module canvas.canvas;
import canvas.backend.common;
import canvas.backend.opengl;
import canvas.color;
import canvas.math;
import canvas.path;
import std.typecons;

final class CanvasRenderingContext {

	private {
		CanvasBackend backend;

		alias backend this;

		Shader vectorShader;
		Shader subpixelShader;
		Shader grayscaleShader;
		Shader blitShader;

		Mesh quad;
		Mesh buffer;

		void delegate() makeContextCurrent;
	}

	this(void delegate() makeContextCurrent) {
		this.makeContextCurrent = makeContextCurrent;
		makeContextCurrent();
		backend = new OpenGLBackend();
		vectorShader = backend.shader([
			ShaderSource(ShaderType.Vertex, import("vector.vert.glsl")),
			ShaderSource(ShaderType.Fragment, import("vector.frag.glsl")),
		]);
		subpixelShader = backend.shader([
			ShaderSource(ShaderType.Vertex, import("identity.vert.glsl")),
			ShaderSource(ShaderType.Fragment, import("subpixel.frag.glsl")),
		]);
		grayscaleShader = backend.shader([
			ShaderSource(ShaderType.Vertex, import("identity.vert.glsl")),
			ShaderSource(ShaderType.Fragment, import("grayscale.frag.glsl")),
		]);
		blitShader = backend.shader([
			ShaderSource(ShaderType.Vertex, import("identity.vert.glsl")),
			ShaderSource(ShaderType.Fragment, import("blit.frag.glsl")),
		]);

		VertexFormat quadVertexFormat;
		quadVertexFormat.add("aPos", AttributeType.FVec2);
		quadVertexFormat.add("aUv", AttributeType.FVec2);
		quad = backend.mesh(quadVertexFormat, MeshUsage.Static);
		quad.upload(cast(void[]) [
			-1.0f, -1.0f, 0.0f, 0.0f,
			 1.0f, -1.0f, 1.0f, 0.0f,
			 1.0f,  1.0f, 1.0f, 1.0f,
			-1.0f,  1.0f, 0.0f, 1.0f,
		]);

		VertexFormat bufferVertexFormat;
		bufferVertexFormat.add("aPos", AttributeType.FVec2);
		bufferVertexFormat.add("aUv", AttributeType.FVec2);
		buffer = backend.mesh(bufferVertexFormat, MeshUsage.Dynamic);
	}

	void dispose() {
		backend.dispose();
	}

}

enum FillRule {
	NonZero,
	EvenOdd,
}

enum PixelOrder {
	Flat,
	HorizontalRGB,
	HorizontalBGR,
	VerticalRGB,
	VerticalBGR,
}

struct LcdPixelLayout {
	PixelOrder order = PixelOrder.HorizontalRGB;
	double contrast = 1.0;
}

enum Antialias {

	None,

	Grayscale,

	/**

	Uses subpixel antialiasing.

	This antialiasing mode requires the entire canvas to be opaque; unintended visual artifacts may occur if this is not the case.

	This will also ignore any blending mode specified and use $(REF BlendingMode.Normal).

	*/
	Subpixel,

}

struct FillOptions {
	Color tint = Color(0, 0, 0);
	Mat3 transform;
	FillRule fillRule = FillRule.NonZero;
	Antialias antialias = Antialias.Grayscale;
	// BlendingMode blendingMode = BlendingMode.Normal;
	LcdPixelLayout subpixelLayout;
	Material material;
	Mat3 materialTransform;
	Canvas texture;
	Mat3 textureTransform;
}

final class Material {
private:
	Shader grayscale;
	Shader subpixel;
}

final class Canvas {

	private CanvasRenderingContext _context;

	/** The primary framebuffer onto which canvas operations render */
	private Framebuffer target;

	/** A framebuffer used temporarily during drawing operations by the canvas implementation */
	private Framebuffer temp;

	private IVec2 _size;

	this(CanvasRenderingContext context, IVec2 size) {
		this._context = context;
		this.size = size;
	}

	inout(CanvasRenderingContext) context() inout @property {
		return _context;
	}

	Material createMaterial(string source) {
		import std.array : replaceFirst;

		context.makeContextCurrent();

		Material result = new Material;
		result.grayscale = context.shader([
			ShaderSource(ShaderType.Vertex, import("identity.vert.glsl")),
			ShaderSource(ShaderType.Fragment, import("custom-grayscale.frag.glsl").replaceFirst("//%mainImage%", source)),
		]);
		result.subpixel = context.shader([
			ShaderSource(ShaderType.Vertex, import("identity.vert.glsl")),
			ShaderSource(ShaderType.Fragment, import("custom-subpixel.frag.glsl").replaceFirst("//%mainImage%", source)),
		]);
		return result;
	}

	IVec2 size() {
		return _size;
	}

	/** Resizes the canvas. The contents of the canvas after this operation are unspecified */
	void size(IVec2 newSize) {
		if (newSize.x < 1) newSize.x = 1;
		if (newSize.y < 1) newSize.y = 1;

		if (newSize == _size) {
			return;
		}

		if (target) {
			target.dispose();
			temp.dispose();
		}

		scope (failure) {
			target = null;
			temp = null;
		}

		context.makeContextCurrent();

		target = context.framebuffer(newSize);
		temp = context.framebuffer(newSize);

		_size = newSize;
	}

	void clear(Color color) {
		context.makeContextCurrent();

		context.renderTarget = target;
		context.clearColor(color);
	}

	void fill(Path path, FillOptions options) {
		import std.math : floor, ceil;
		import std.algorithm : map;

		struct Vertex {
			Vec2 point;
			Vec2 uv;
		}

		auto points = path.values.map!(x => options.transform * x);
		if (points.length == 0) {
			return;
		}

		context.makeContextCurrent();

		context.renderTarget = target;
		context.viewport(IVec2(0, 0), size);

		try {
			context.vectorShader.setUniform("uViewportSize", cast(FVec2) size);
		}
		catch (OpenGLException e) { // TODO: wtf???? sometimes the above just *fails* but retrying seems to work 100% of the time
			context.vectorShader.setUniform("uViewportSize", cast(FVec2) size);
		}

		double minX = double.infinity;
		double maxX = -double.infinity;
		double minY = double.infinity;
		double maxY = -double.infinity;
		foreach (point; points) {
			if (point.x < minX) minX = point.x;
			if (point.x > maxX) maxX = point.x;
			if (point.y < minY) minY = point.y;
			if (point.y > maxY) maxY = point.y;
		}
		minX = floor(minX - 1);
		minY = floor(minY - 1);
		maxX = ceil(maxX + 1);
		maxY = ceil(maxY + 1);

		Vertex[3][] geometry;

		size_t pointIndex;
		Vec2 lastMove;
		Vec2 lastPoint;
		foreach (cmd; path.commands) {
			final switch (cmd) {
			case PathCommand.Move:
				auto point = points[pointIndex++];
				lastMove = point;
				lastPoint = point;
				break;
			case PathCommand.Close:
				lastPoint = lastMove;
				break;
			case PathCommand.Line:
				auto point = points[pointIndex++];
				geometry ~= [
					Vertex(lastMove, Vec2()),
					Vertex(lastPoint, Vec2()),
					Vertex(point, Vec2()),
				];
				lastPoint = point;
				break;
			case PathCommand.QuadCurve:
				auto control = points[pointIndex++];
				auto point = points[pointIndex++];
				geometry ~= [
					Vertex(lastMove, Vec2()),
					Vertex(lastPoint, Vec2()),
					Vertex(point, Vec2()),
				];
				geometry ~= [
					Vertex(lastPoint, Vec2(0, 0)),
					Vertex(control, Vec2(1, 0)),
					Vertex(point, Vec2(0, 1)),
				];
				lastPoint = point;
				break;
			case PathCommand.CubicCurve:
				auto start = lastPoint;
				auto control1 = points[pointIndex++];
				auto control2 = points[pointIndex++];
				auto point = points[pointIndex++];
				Vec2 compute(double alpha) {
					auto p1 = start * (1 - alpha) + control1 * alpha;
					auto p2 = control1 * (1 - alpha) + control2 * alpha;
					auto p3 = control2 * (1 - alpha) + point * alpha;
					auto q1 = p1 * (1 - alpha) + p2 * alpha;
					auto q2 = p2 * (1 - alpha) + p3 * alpha;
					return q1 * (1 - alpha) + q2 * alpha;
				}
				foreach (i; 0 .. 64) {
					auto alpha = (i + 1) / 64.0;
					auto r = compute(alpha);
					auto c = compute((i + 0.5) / 64.0); // TODO: more accurate rendering
					geometry ~= [
						Vertex(lastMove, Vec2()),
						Vertex(lastPoint, Vec2()),
						Vertex(r, Vec2()),
					];
					geometry ~= [
						Vertex(lastPoint, Vec2(0, 0)),
						Vertex(c, Vec2(1, 0)),
						Vertex(r, Vec2(0, 1)),
					];
					lastPoint = r;
				}
				break;
			}
		}

		FVec2[] data;

		foreach (triangle; geometry) {
			data ~= FVec2(triangle[0].point);
			data ~= FVec2(triangle[0].uv);
			data ~= FVec2(triangle[1].point);
			data ~= FVec2(triangle[1].uv);
			data ~= FVec2(triangle[2].point);
			data ~= FVec2(triangle[2].uv);
		}

		// cover
		data ~= FVec2(minX, minY);
		data ~= FVec2(0, 0);
		data ~= FVec2(minX, maxY);
		data ~= FVec2(0, 0);
		data ~= FVec2(maxX, maxY);
		data ~= FVec2(0, 0);
		data ~= FVec2(maxX, minY);
		data ~= FVec2(0, 0);

		// subpixel cover
		data ~= FVec2(minX, minY) / FVec2(size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(minX, minY) / FVec2(size) * FVec2(1, -1);
		data ~= FVec2(minX, maxY) / FVec2(size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(minX, maxY) / FVec2(size) * FVec2(1, -1);
		data ~= FVec2(maxX, maxY) / FVec2(size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(maxX, maxY) / FVec2(size) * FVec2(1, -1);
		data ~= FVec2(maxX, minY) / FVec2(size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(maxX, minY) / FVec2(size) * FVec2(1, -1);

		context.buffer.upload(cast(void[]) data);

		context.renderTarget = temp;
		context.clearColor(Color(0, 0, 0, 1));
		context.clearStencil(0x00);
		context.blend = BlendingFunctions.Add;

		const(Sample)[] samples;

		if (options.subpixelLayout.order == PixelOrder.Flat
				&& options.antialias == Antialias.Subpixel) {
			options.antialias = Antialias.Grayscale;
		}

		final switch (options.antialias) {
		case Antialias.None:
			samples = aliasedSamples;
			break;
		case Antialias.Grayscale:
			samples = grayscaleSamples;
			break;
		case Antialias.Subpixel:
			samples = rgbSubpixelSamples;
			break;
		}

		foreach (sample; samples) {
			if (options.fillRule == FillRule.EvenOdd) {
				Stencil stencil;
				stencil.pass = StencilOp.Inv;
				context.stencil = stencil;
			}
			else {
				Stencil stencilFront, stencilBack;
				stencilFront.pass = StencilOp.IncWrap;
				stencilBack.pass = StencilOp.DecWrap;
				context.stencilSeparate(stencilFront, stencilBack);
			}

			context.colorWriteMask(false, false, false, false);

			context.vectorShader.setUniform("uColor", sample.color);
			context.vectorShader.setUniform("uTranslate", -sample.translate);

			context.draw(DrawMode.Triangles, context.vectorShader, context.buffer, 0, geometry.length * 3);

			context.colorWriteMask(true, true, true, true);
			Stencil stencil;
			stencil.func = StencilFunction.Neq;
			stencil.refValue = 0;
			stencil.stencilFail = StencilOp.Zero;
			stencil.depthFail = StencilOp.Zero;
			stencil.pass = StencilOp.Zero;
			context.stencil = stencil;
			context.draw(DrawMode.TriangleFan, context.vectorShader, context.buffer, geometry.length * 3, 4);
		}

		context.renderTarget = target;
		context.stencil = Stencil.init;

		Shader shader;

		final switch (options.antialias) {
		case Antialias.Subpixel:
			context.blend = BlendingFunctions.Overwrite;
			shader = options.material ? options.material.subpixel : context.subpixelShader;
			shader.setUniform("uViewportSize", cast(FVec2) size);
			shader.setUniform("uContrastFactor", options.subpixelLayout.contrast);
			shader.setUniform("uTarget", target);
			break;
		case Antialias.None:
		case Antialias.Grayscale:
			context.blend = BlendingFunctions.Normal;
			shader = options.material ? options.material.grayscale : context.grayscaleShader;
			break;
		}

		shader.setUniform("uColor", options.tint);
		shader.setUniform("uSource", temp);

		if (options.texture !is null) {
			shader.setUniform("uTextureEnabled", 1);

			if (options.texture.context !is context) {
				throw new Exception("Cannot use canvas from another context as texture");
			}

			shader.setUniform("uTexture", options.texture.target);
		}
		else {
			shader.setUniform("uTextureEnabled", 0);
		}

		shader.setUniform("uTextureTransform", FMat3(options.textureTransform));

		if (options.material !is null) {
			shader.setUniform("uMaterialTransform", FMat3(options.materialTransform));
		}

		// shader.setUniform("uTexture", fill.texture);
		// shader.setUniform("uTextureTransform", FMat3(fill.textureTransform));
		// shader.setUniform("uTextureEnabled", fill.texture ? 1 : 0);

		context.draw(DrawMode.TriangleFan, shader, context.buffer, geometry.length * 3 + 4, 4);

		if (options.texture !is null) {
			shader.setUniform("uTexture", null); // TODO: figure out why this is needed
			// otherwise, if you draw a canvas onto another canvas and you resize the former canvas, it crashes
		}
	}

	void fillIRect(IVec2 pos, IVec2 size, FillOptions options) {
		import std.math : floor, ceil;
		import std.algorithm : map;

		context.makeContextCurrent();

		context.renderTarget = target;
		context.viewport(IVec2(0, 0), this.size);

		double minX = pos.x, minY = pos.y;
		double maxX = pos.x + size.x, maxY = pos.y + size.y;

		FVec2[] data;

		data ~= FVec2(minX, minY) / FVec2(this.size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(minX, minY) / FVec2(this.size) * FVec2(1, -1);
		data ~= FVec2(minX, maxY) / FVec2(this.size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(minX, maxY) / FVec2(this.size) * FVec2(1, -1);
		data ~= FVec2(maxX, maxY) / FVec2(this.size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(maxX, maxY) / FVec2(this.size) * FVec2(1, -1);
		data ~= FVec2(maxX, minY) / FVec2(this.size) * FVec2(2, -2) + FVec2(-1, 1);
		data ~= FVec2(maxX, minY) / FVec2(this.size) * FVec2(1, -1);

		context.buffer.upload(cast(void[]) data);

		context.renderTarget = temp;
		context.clearColor(Color(1, 0, 0, 1));
		context.renderTarget = target;
		context.stencil = Stencil.init;

		Shader shader;

		context.blend = BlendingFunctions.Normal;
		shader = options.material ? options.material.grayscale : context.grayscaleShader;

		shader.setUniform("uColor", options.tint);
		shader.setUniform("uSource", temp);

		if (options.texture !is null) {
			shader.setUniform("uTextureEnabled", 1);

			if (options.texture.context !is context) {
				throw new Exception("Cannot use canvas from another context as texture");
			}

			shader.setUniform("uTexture", options.texture.target);
		}
		else {
			shader.setUniform("uTextureEnabled", 0);
		}

		shader.setUniform("uTextureTransform", FMat3(options.textureTransform));

		if (options.material !is null) {
			shader.setUniform("uMaterialTransform", FMat3(options.materialTransform));
		}

		context.draw(DrawMode.TriangleFan, shader, context.buffer, 0, 4);

		if (options.texture !is null) {
			shader.setUniform("uTexture", null); // TODO: figure out why this is needed
			// otherwise, if you draw a canvas onto another canvas and you resize the former canvas, it crashes
		}
	}

}

void blitToScreen(Canvas canvas, IVec2 viewportSize) {
	canvas.context.viewport(IVec2(0, 0), viewportSize);
	canvas.context.renderTarget = null;

	canvas.context.blitShader.setUniform("uTexture", canvas.target);

	canvas.context.draw(DrawMode.TriangleFan, canvas.context.blitShader, canvas.context.quad, 0, 4);
}

private:

struct Sample {
	FVec2 translate;
	FVec4 color;
}

immutable(Sample[]) rgbSubpixelSamples = [
	// near subpixel
	Sample(FVec2(1 - 5.5 / 12.0,  0.5 / 4.0), FVec4(0.25, 0, 0, 0)),
	Sample(FVec2(1 - 4.5 / 12.0, -1.5 / 4.0), FVec4(0.25, 0, 0, 0)),
	Sample(FVec2(1 - 3.5 / 12.0,  1.5 / 4.0), FVec4(0.25, 0, 0, 0)),
	Sample(FVec2(1 - 2.5 / 12.0, -0.5 / 4.0), FVec4(0.25, 0, 0, 0)),

	// center subpixel
	Sample(FVec2(-1.5 / 12.0,  0.5 / 4.0), FVec4(0, 0.25, 0, 0)),
	Sample(FVec2(-0.5 / 12.0, -1.5 / 4.0), FVec4(0, 0.25, 0, 0)),
	Sample(FVec2( 0.5 / 12.0,  1.5 / 4.0), FVec4(0, 0.25, 0, 0)),
	Sample(FVec2( 1.5 / 12.0, -0.5 / 4.0), FVec4(0, 0.25, 0, 0)),

	// far subpixel
	Sample(FVec2( 2.5 / 12.0,  0.5 / 4.0), FVec4(0, 0, 0.25, 0)),
	Sample(FVec2( 3.5 / 12.0, -1.5 / 4.0), FVec4(0, 0, 0.25, 0)),
	Sample(FVec2( 4.5 / 12.0,  1.5 / 4.0), FVec4(0, 0, 0.25, 0)),
	Sample(FVec2( 5.5 / 12.0, -0.5 / 4.0), FVec4(0, 0, 0.25, 0)),
];

immutable(Sample[]) grayscaleSamples = [
	Sample(FVec2(-3.5 / 8.0, -1.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2(-2.5 / 8.0,  2.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2(-1.5 / 8.0, -2.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2(-0.5 / 8.0,  0.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2( 0.5 / 8.0, -3.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2( 1.5 / 8.0,  3.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2( 2.5 / 8.0, -0.5 / 8.0), FVec4(0.125, 0, 0, 0)),
	Sample(FVec2( 3.5 / 8.0,  1.5 / 8.0), FVec4(0.125, 0, 0, 0)),
];

immutable(Sample[]) aliasedSamples = [
	Sample(FVec2(0, 0), FVec4(1, 0, 0, 0)),
];
