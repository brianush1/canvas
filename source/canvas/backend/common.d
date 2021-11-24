module canvas.backend.common;
import canvas.color;
import canvas.math;

// Enums:

enum ShaderType {
	Fragment,
	Vertex,
}

enum DrawMode {
	Triangles,
	TriangleFan,
	TriangleStrip,
}

enum MeshUsage {

	/** Signals that the mesh will not be modified often */
	Static,

	/** Signals that the mesh will be modified often */
	Dynamic,

}

enum AttributeType {
	Float,
	FVec2,
	FVec3,
	FVec4,
	Int,
	IVec2,
	IVec3,
	IVec4,
}

size_t byteLength(AttributeType type) {
	final switch (type) {
		case AttributeType.Float: return float.sizeof;
		case AttributeType.FVec2: return FVec2.sizeof;
		case AttributeType.FVec3: return FVec3.sizeof;
		case AttributeType.FVec4: return FVec4.sizeof;
		case AttributeType.Int: return int.sizeof;
		case AttributeType.IVec2: return IVec2.sizeof;
		case AttributeType.IVec3: return IVec3.sizeof;
		case AttributeType.IVec4: return IVec4.sizeof;
	}
}

enum StencilFunction {
	Always,
	Never,
	Lt,
	Le,
	Gt,
	Ge,
	Eq,
	Neq,
}

enum StencilOp {
	Nop,
	Zero,
	Set,
	Inc,
	Dec,
	IncWrap,
	DecWrap,
	Inv,
}

// Structs:

struct ShaderSource {
	ShaderType type;
	string source;
}

struct Attribute {
	string name;
	AttributeType type;
	size_t byteOffset;
}

struct VertexFormat {
	Attribute[] attributes;
	size_t stride;

	void add(string name, AttributeType type) {
		// TODO: bind to input based on name; currently uses order
		attributes ~= Attribute(name, type, stride);
		stride += type.byteLength;
	}
}

struct Stencil {

	StencilFunction func = StencilFunction.Always;
	StencilOp stencilFail = StencilOp.Nop;
	StencilOp depthFail = StencilOp.Nop;
	StencilOp pass = StencilOp.Nop;
	ubyte refValue = 0;
	ubyte writeMask = 0xFF;
	ubyte readMask = 0xFF;
}

struct BlendingFunction {
	enum Factor {
		Zero,
		One,
		SrcColor,
		DstColor,
		SrcAlpha,
		DstAlpha,
		ConstColor,
		ConstAlpha,
		OneMinusSrcColor,
		OneMinusDstColor,
		OneMinusSrcAlpha,
		OneMinusDstAlpha,
		OneMinusConstColor,
		OneMinusConstAlpha,
	}

	enum Operation {
		Add,
		SrcMinusDst,
		DstMinusSrc,
		Min,
		Max,
	}

	Operation op;
	Factor sfactor;
	Factor dfactor;
	FVec4 constant = FVec4(0, 0, 0, 0);
}

enum BlendingFunctions : BlendingFunction {
	Normal = BlendingFunction(
		BlendingFunction.Operation.Add,
		BlendingFunction.Factor.SrcAlpha,
		BlendingFunction.Factor.OneMinusSrcAlpha,
	),
	Overwrite = BlendingFunction(
		BlendingFunction.Operation.Add,
		BlendingFunction.Factor.One,
		BlendingFunction.Factor.Zero,
	),
	Add = BlendingFunction(
		BlendingFunction.Operation.Add,
		BlendingFunction.Factor.One,
		BlendingFunction.Factor.One,
	),
}

// Resources:

abstract class Shader {

	/**

	Releases all resources used by the shader

	Calling any method on the shader, including $(REF dispose), after it has been disposed is undefined behavior

	*/
	void dispose();

	void setUniform(string name, float value);
	void setUniform(string name, int value);
	void setUniform(string name, FVec2 value);
	void setUniform(string name, FVec3 value);
	void setUniform(string name, FVec4 value);
	void setUniform(string name, Color value);
	void setUniform(string name, IVec2 value);
	void setUniform(string name, IVec3 value);
	void setUniform(string name, IVec4 value);
	void setUniform(string name, FMat3 value);
	void setUniform(string name, Texture value);

}

abstract class Mesh {

	/**

	Releases all resources used by the mesh

	Calling any method on the mesh, including $(REF dispose), after it has been disposed is undefined behavior

	*/
	void dispose();

	void upload(void[] data);

}

abstract class Texture {

	/**

	Releases all resources used by the texture

	Calling any method on the texture, including $(REF dispose), after it has been disposed is undefined behavior

	*/
	void dispose();

	IVec2 size();

}

abstract class Framebuffer : Texture {}

abstract class CanvasBackend {

	/** Releases all resources created under this backend */
	void dispose();

	/** Creates a new shader from the given sources */
	Shader shader(ShaderSource[] sources);

	Mesh mesh(VertexFormat format, MeshUsage usage);

	Framebuffer framebuffer(IVec2 size);

	Texture texture(IVec2 size, const(void)[] data);

	/**

	Sets the current rendering target

	Pass in $(D null) to draw onto the main window

	*/
	void renderTarget(Framebuffer framebuffer);

	/** Gets the current rendering target, or $(D null) */
	Framebuffer renderTarget();

	/** Clears the color buffer with the given color */
	void clearColor(Color color);

	/** Clears the stencil buffer with the given value */
	void clearStencil(ubyte value);

	void stencil(Stencil value);

	void stencilSeparate(Stencil front, Stencil back);

	/** Gets the color channel blending function */
	BlendingFunction colorBlend();

	/** Gets the alpha channel blending function */
	BlendingFunction alphaBlend();

	/** Same as $(REF colorBlend) */
	BlendingFunction blend();

	void blend(BlendingFunction value);

	void blend(BlendingFunction color, BlendingFunction alpha);

	/** Sets the viewport rectangle */
	void viewport(IVec2 location, IVec2 size);

	void colorWriteMask(bool r, bool g, bool b, bool a);

	void draw(DrawMode mode, Shader shader, Mesh mesh, size_t startVertex, size_t numVertices);

}
