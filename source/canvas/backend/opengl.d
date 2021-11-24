module canvas.backend.opengl;
import canvas.backend.common;
import canvas.color;
import canvas.math;
import bindbc.opengl;

private void[] flipImage(size_t width, size_t height, const(void)[] data) {
	void[] result = new void[4 * width * height];
	size_t length = 4 * width;
	foreach (j; 0 .. height) {
		size_t index1 = j * 4 * width;
		size_t index2 = (height - j - 1) * 4 * width;
		result[index1 .. index1 + length] = data[index2 .. index2 + length];
	}
	return result;
}

private interface OpenGLResource {

	void dispose();

}

final class OpenGLException : Exception {

	this(string msg, string file = __FILE__, size_t line = __LINE__) @nogc @safe pure nothrow {
		super(msg, file, line);
	}

}

final class OpenGLShader : Shader, OpenGLResource {

	private {
		OpenGLBackend context;

		GLuint program;

		GLint[string] uniformLocations;
	}

	private this(OpenGLBackend context, ShaderSource[] sources) {
		import std.conv : to;

		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Create OpenGL shader %p"(cast(void*) this);
		}

		this.context = context;

		program = glCreateProgram();
		if (program == 0) {
			throw new OpenGLException("Could not create shader program");
		}

		GLuint[] shaders;

		foreach (source; sources) {
			GLenum type;
			final switch (source.type) {
			case ShaderType.Fragment:
				type = GL_FRAGMENT_SHADER;
				break;
			case ShaderType.Vertex:
				type = GL_VERTEX_SHADER;
				break;
			}

			GLuint shader = glCreateShader(type);
			if (shader == 0) {
				foreach (s; shaders) {
					glDeleteShader(s);
				}

				glDeleteProgram(program);

				throw new OpenGLException("Could not create " ~ source.type.to!string ~ " shader");
			}

			const(char)* src = source.source.ptr;

			if (source.source.length > GLint.max) {
				throw new OpenGLException("Length of " ~ source.type.to!string ~ " shader is too large");
			}

			GLint length = cast(GLint) source.source.length;

			glShaderSource(shader, 1, &src, &length);

			glCompileShader(shader);

			GLint success;
			glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
			if (!success) {
				import std.exception : assumeUnique;

				GLint size;
				glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &size);

				if (size <= 1) {
					throw new OpenGLException(source.type.to!string ~ " shader compilation failed");
				}

				char[] buf = new char[size - 1];
				glGetShaderInfoLog(shader, size - 1, null, buf.ptr);

				throw new OpenGLException(source.type.to!string ~ " shader compilation failed: " ~ buf.assumeUnique);
			}

			shaders ~= shader;
		}

		foreach (shader; shaders) {
			glAttachShader(program, shader);
		}

		glLinkProgram(program);

		GLint success;
		glGetProgramiv(program, GL_LINK_STATUS, &success);
		if (!success) {
			import std.exception : assumeUnique;

			GLint size;
			glGetProgramiv(program, GL_INFO_LOG_LENGTH, &size);

			if (size <= 1) {
				throw new OpenGLException("Shader linking failed");
			}

			char[] buf = new char[size - 1];
			glGetProgramInfoLog(program, size - 1, null, buf.ptr);

			throw new OpenGLException("Shader linking failed: " ~ buf.assumeUnique);
		}

		foreach (shader; shaders) {
			glDeleteShader(shader);
		}
	}

	override void dispose() {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Delete OpenGL shader %p"(cast(void*) this);
		}

		glDeleteProgram(program);

		context.resources.remove(this);
	}

	private void useShader() {
		if (context.shaderInUse !is this) {
			context.shaderInUse = this;
			glUseProgram(program);
		}
	}

	private GLint getUniformLocation(string name) {
		import std.string : toStringz;

		if (name in uniformLocations) {
			return uniformLocations[name];
		}

		GLint result = glGetUniformLocation(program, name.toStringz);

		uniformLocations[name] = result;
		return result;
	}

	override void setUniform(string name, float value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform1f(uniformLocation, value);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to float value");
		}
	}

	override void setUniform(string name, int value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform1i(uniformLocation, value);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to int value");
		}
	}

	override void setUniform(string name, FVec2 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform2f(uniformLocation, value.x, value.y);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to FVec2 value");
		}
	}

	override void setUniform(string name, FVec3 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform3f(uniformLocation, value.x, value.y, value.z);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to FVec3 value");
		}
	}

	override void setUniform(string name, FVec4 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform4f(uniformLocation, value.x, value.y, value.z, value.w);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to FVec4 value");
		}
	}

	override void setUniform(string name, Color value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform4f(uniformLocation, value.r, value.g, value.b, value.a);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to Color value");
		}
	}

	override void setUniform(string name, IVec2 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform2i(uniformLocation, value.x, value.y);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to IVec2 value");
		}
	}

	override void setUniform(string name, IVec3 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform3i(uniformLocation, value.x, value.y, value.z);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to IVec3 value");
		}
	}

	override void setUniform(string name, IVec4 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniform4i(uniformLocation, value.x, value.y, value.z, value.w);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to IVec4 value");
		}
	}

	override void setUniform(string name, FMat3 value) {
		useShader();

		GLint uniformLocation = getUniformLocation(name);
		if (uniformLocation == -1) {
			return;
		}

		glUniformMatrix3fv(uniformLocation, 1, true, cast(const(GLfloat)*)&value);
		if (glGetError() != GL_NO_ERROR) {
			throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to FMat3 value");
		}
	}

	private {
		size_t[string] textureLocations;
		Texture[] textures;
		int currTexture;

		size_t assignTexture(string name) {
			if (name !in textureLocations) {
				useShader();

				GLint uniformLocation = getUniformLocation(name);
				if (uniformLocation == -1) {
					return -1;
				}

				glUniform1i(uniformLocation, currTexture);
				if (glGetError() != GL_NO_ERROR) {
					throw new OpenGLException("An error occurred while setting uniform '" ~ name ~ "' to texture value");
				}

				textureLocations[name] = currTexture;
				textures ~= null;
				currTexture += 1;
			}
			return textureLocations[name];
		}
	}

	override void setUniform(string name, Texture value) {
		if (value && !cast(OpenGLFramebuffer) value && !cast(OpenGLTexture) value) {
			throw new OpenGLException("Cannot set OpenGL uniform to non-OpenGL texture");
		}

		size_t texture = assignTexture(name);
		if (texture == -1) {
			return;
		}

		textures[texture] = value;
	}

}

final class OpenGLMesh : Mesh, OpenGLResource {

	private {
		OpenGLBackend context;

		GLuint vao, buffer;

		MeshUsage usage;
	}

	private this(OpenGLBackend context, VertexFormat format, MeshUsage usage) {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Create OpenGL mesh %p"(cast(void*) this);
		}

		this.context = context;
		this.usage = usage;

		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);

		glGenBuffers(1, &buffer);
		glBindBuffer(GL_ARRAY_BUFFER, buffer);

		foreach (i, v; format.attributes) {
			GLint size;
			GLenum type;
			final switch (v.type) {
			case AttributeType.Float:
				size = 1;
				type = GL_FLOAT;
				break;
			case AttributeType.FVec2:
				size = 2;
				type = GL_FLOAT;
				break;
			case AttributeType.FVec3:
				size = 3;
				type = GL_FLOAT;
				break;
			case AttributeType.FVec4:
				size = 4;
				type = GL_FLOAT;
				break;
			case AttributeType.Int:
				size = 1;
				type = GL_INT;
				break;
			case AttributeType.IVec2:
				size = 2;
				type = GL_INT;
				break;
			case AttributeType.IVec3:
				size = 3;
				type = GL_INT;
				break;
			case AttributeType.IVec4:
				size = 4;
				type = GL_INT;
				break;
			}
			glVertexAttribPointer(cast(GLuint) i, size, type, false,
				cast(GLsizei) format.stride, cast(void*) v.byteOffset);
			glEnableVertexAttribArray(cast(GLuint) i);
		}
	}

	override void dispose() {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Delete OpenGL mesh %p"(cast(void*) this);
		}

		glDeleteVertexArrays(1, &vao);
		glDeleteBuffers(1, &buffer);

		context.resources.remove(this);
	}

	override void upload(void[] data) {
		glBindVertexArray(vao);
		glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr) data.length, data.ptr,
			usage == MeshUsage.Dynamic ? GL_STREAM_DRAW : GL_STATIC_DRAW,
		);
	}

}

final class OpenGLTexture : Texture, OpenGLResource {

	private {
		OpenGLBackend context;

		GLuint texture;

		IVec2 _size;
	}

	private this(OpenGLBackend context, IVec2 size, const(void)[] data) {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Create OpenGL texture %p"(cast(void*) this);
		}

		this.context = context;
		_size = size;

		glGenTextures(1, &texture);
		glBindTexture(GL_TEXTURE_2D, texture);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
			cast(GLsizei) size.x, cast(GLsizei) size.y,
			0, GL_RGBA, GL_UNSIGNED_BYTE, flipImage(size.x, size.y, data).ptr);
	}

	override void dispose() {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Delete OpenGL texture %p"(cast(void*) this);
		}

		glDeleteTextures(1, &texture);

		context.resources.remove(this);
	}

	override IVec2 size() {
		return _size;
	}

}

final class OpenGLFramebuffer : Framebuffer, OpenGLResource {

	private {
		OpenGLBackend context;

		GLuint fbo, rbo, texColorBuffer;

		IVec2 _size;
	}

	private this(OpenGLBackend context, IVec2 size) {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Create OpenGL framebuffer %p"(cast(void*) this);
		}

		this.context = context;
		_size = size;

		glGenFramebuffers(1, &fbo);

		glBindFramebuffer(GL_FRAMEBUFFER, fbo);

		glGenTextures(1, &texColorBuffer);
		glBindTexture(GL_TEXTURE_2D, texColorBuffer);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
			cast(GLsizei) size.x, cast(GLsizei) size.y,
			0, GL_RGBA, GL_UNSIGNED_BYTE, null);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glBindTexture(GL_TEXTURE_2D, 0);

		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
			GL_TEXTURE_2D, texColorBuffer, 0);
		
		glGenRenderbuffers(1, &rbo);

		glBindRenderbuffer(GL_RENDERBUFFER, rbo);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8,
			cast(GLsizei) size.x, cast(GLsizei) size.y);
		glBindRenderbuffer(GL_RENDERBUFFER, 0);

		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
			GL_RENDERBUFFER, rbo);

		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
			throw new OpenGLException("An error occurred while creating a framebuffer");
		}

		if (context._renderTarget) {
			glBindFramebuffer(GL_FRAMEBUFFER, (cast(OpenGLFramebuffer) context._renderTarget).fbo);
		}
		else {
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
		}
	}

	override void dispose() {
		debug (resourceTracking) {
			import std.stdio : writeln;

			writefln!"Delete OpenGL framebuffer %p"(cast(void*) this);
		}

		glDeleteRenderbuffers(1, &rbo);
		glDeleteTextures(1, &texColorBuffer);
		glDeleteFramebuffers(1, &fbo);

		context.resources.remove(this);
	}

	override IVec2 size() {
		return _size;
	}

}

final class OpenGLBackend : CanvasBackend {

	private OpenGLShader shaderInUse;

	this() {
		GLSupport gl = .loadOpenGL(); // TODO: if you wanna do multicontext on Windows,
		// apparently loadOpenGL needs to be called after every context switch?
		if (gl < GLSupport.gl33) {
			throw new Exception("Could not load OpenGL 3.3 or above");
		}

		glDisable(GL_MULTISAMPLE);
	}

	private bool[OpenGLResource] resources;

	override void dispose() {
		import std.array : array;

		foreach (resource; resources.byKey.array) {
			resource.dispose();
		}

		// TODO: unloadOpenGL?
	}

	override Shader shader(ShaderSource[] sources) {
		return new OpenGLShader(this, sources);
	}

	override Mesh mesh(VertexFormat format, MeshUsage usage) {
		return new OpenGLMesh(this, format, usage);
	}

	override Framebuffer framebuffer(IVec2 size) {
		return new OpenGLFramebuffer(this, size);
	}

	override Texture texture(IVec2 size, const(void)[] data) {
		return new OpenGLTexture(this, size, data);
	}

	private Framebuffer _renderTarget;

	override void renderTarget(Framebuffer framebuffer) {
		if (framebuffer && !cast(OpenGLFramebuffer) framebuffer) {
			throw new OpenGLException("Cannot bind non-OpenGL framebuffer to OpenGL context");
		}

		if (framebuffer !is _renderTarget) {
			_renderTarget = framebuffer;
			if (framebuffer) {
				glBindFramebuffer(GL_FRAMEBUFFER, (cast(OpenGLFramebuffer) framebuffer).fbo);
			}
			else {
				glBindFramebuffer(GL_FRAMEBUFFER, 0);
			}
		}
	}

	override Framebuffer renderTarget() {
		return _renderTarget;
	}

	override void clearColor(Color color) {
		glClearColor(color.r, color.g, color.b, color.a);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	override void clearStencil(ubyte value) {
		glClearStencil(value);
		glClear(GL_STENCIL_BUFFER_BIT);
	}

	override void stencil(Stencil value) {
		stencilSeparate(value, value);
	}

	override void stencilSeparate(Stencil front, Stencil back) {
		GLenum convStencilFunc(StencilFunction func) {
			final switch (func) {
				case StencilFunction.Always: return GL_ALWAYS;
				case StencilFunction.Never: return GL_NEVER;
				case StencilFunction.Lt: return GL_LESS;
				case StencilFunction.Le: return GL_LEQUAL;
				case StencilFunction.Gt: return GL_GREATER;
				case StencilFunction.Ge: return GL_GEQUAL;
				case StencilFunction.Eq: return GL_EQUAL;
				case StencilFunction.Neq: return GL_NOTEQUAL;
			}
		}

		GLenum convStencilOp(StencilOp op) {
			final switch (op) {
				case StencilOp.Nop: return GL_KEEP;
				case StencilOp.Zero: return GL_ZERO;
				case StencilOp.Set: return GL_REPLACE;
				case StencilOp.Inc: return GL_INCR;
				case StencilOp.Dec: return GL_DECR;
				case StencilOp.IncWrap: return GL_INCR_WRAP;
				case StencilOp.DecWrap: return GL_DECR_WRAP;
				case StencilOp.Inv: return GL_INVERT;
			}
		}

		if (front.func == StencilFunction.Always
				&& front.stencilFail == StencilOp.Nop
				&& front.depthFail == StencilOp.Nop
				&& front.pass == StencilOp.Nop
				&& back.func == StencilFunction.Always
				&& back.stencilFail == StencilOp.Nop
				&& back.depthFail == StencilOp.Nop
				&& back.pass == StencilOp.Nop) {
			glDisable(GL_STENCIL_TEST);
			return;
		}

		glEnable(GL_STENCIL_TEST);

		if (front.writeMask == back.writeMask) {
			glStencilMask(front.writeMask);
		}
		else {
			glStencilMaskSeparate(GL_FRONT, front.writeMask);
			glStencilMaskSeparate(GL_BACK, back.writeMask);
		}

		if (front.func == back.func && front.refValue == back.refValue && front.readMask == back.readMask) {
			glStencilFunc(convStencilFunc(front.func), front.refValue, front.readMask);
		}
		else {
			glStencilFuncSeparate(GL_FRONT, convStencilFunc(front.func), front.refValue, front.readMask);
			glStencilFuncSeparate(GL_BACK, convStencilFunc(back.func), back.refValue, back.readMask);
		}

		if (front.stencilFail == back.stencilFail && front.depthFail == back.depthFail && front.pass == back.pass) {
			glStencilOp(
				convStencilOp(front.stencilFail),
				convStencilOp(front.depthFail),
				convStencilOp(front.pass),
			);
		}
		else {
			glStencilOpSeparate(GL_FRONT,
				convStencilOp(front.stencilFail),
				convStencilOp(front.depthFail),
				convStencilOp(front.pass),
			);
			glStencilOpSeparate(GL_BACK,
				convStencilOp(back.stencilFail),
				convStencilOp(back.depthFail),
				convStencilOp(back.pass),
			);
		}
	}

	private BlendingFunction _colorBlend;
	private BlendingFunction _alphaBlend;

	override BlendingFunction colorBlend() const { return _colorBlend; }
	override BlendingFunction alphaBlend() const { return _alphaBlend; }
	override BlendingFunction blend() const { return _colorBlend; }

	override void blend(BlendingFunction value) {
		blend(value, value);
	}

	private GLenum convBlendingOperation(BlendingFunction.Operation op) {
		final switch (op) {
			case BlendingFunction.Operation.Add: return GL_FUNC_ADD;
			case BlendingFunction.Operation.SrcMinusDst: return GL_FUNC_SUBTRACT;
			case BlendingFunction.Operation.DstMinusSrc: return GL_FUNC_REVERSE_SUBTRACT;
			case BlendingFunction.Operation.Min: return GL_MIN;
			case BlendingFunction.Operation.Max: return GL_MAX;
		}
	}

	private GLenum convBlendingFactor(BlendingFunction.Factor factor) {
		final switch (factor) {
			case BlendingFunction.Factor.Zero: return GL_ZERO;
			case BlendingFunction.Factor.One: return GL_ONE;
			case BlendingFunction.Factor.SrcColor: return GL_SRC_COLOR;
			case BlendingFunction.Factor.DstColor: return GL_DST_COLOR;
			case BlendingFunction.Factor.SrcAlpha: return GL_SRC_ALPHA;
			case BlendingFunction.Factor.DstAlpha: return GL_DST_ALPHA;
			case BlendingFunction.Factor.ConstColor: return GL_CONSTANT_COLOR;
			case BlendingFunction.Factor.ConstAlpha: return GL_CONSTANT_ALPHA;
			case BlendingFunction.Factor.OneMinusSrcColor: return GL_ONE_MINUS_SRC_COLOR;
			case BlendingFunction.Factor.OneMinusDstColor: return GL_ONE_MINUS_DST_COLOR;
			case BlendingFunction.Factor.OneMinusSrcAlpha: return GL_ONE_MINUS_SRC_ALPHA;
			case BlendingFunction.Factor.OneMinusDstAlpha: return GL_ONE_MINUS_DST_ALPHA;
			case BlendingFunction.Factor.OneMinusConstColor: return GL_ONE_MINUS_CONSTANT_COLOR;
			case BlendingFunction.Factor.OneMinusConstAlpha: return GL_ONE_MINUS_CONSTANT_ALPHA;
		}
	}

	override void blend(BlendingFunction color, BlendingFunction alpha) {
		_colorBlend = color;
		_alphaBlend = alpha;

		if (color == BlendingFunctions.Overwrite && alpha == color) {
			// technically doesn't catch all functions equivalent to disabling blending
			// but it's good enough
			glDisable(GL_BLEND);
			return;
		}

		glEnable(GL_BLEND);

		if (color.op == alpha.op) {
			glBlendEquation(convBlendingOperation(color.op));
		}
		else {
			glBlendEquationSeparate(
				convBlendingOperation(color.op),
				convBlendingOperation(alpha.op),
			);
		}

		if (color.sfactor == alpha.sfactor && color.dfactor == alpha.dfactor) {
			glBlendFunc(
				convBlendingFactor(color.sfactor),
				convBlendingFactor(color.dfactor),
			);
		}
		else {
			glBlendFuncSeparate(
				convBlendingFactor(color.sfactor),
				convBlendingFactor(color.dfactor),
				convBlendingFactor(alpha.sfactor),
				convBlendingFactor(alpha.dfactor),
			);
		}

		glBlendColor(
			color.constant.r,
			color.constant.g,
			color.constant.b,
			alpha.constant.a,
		);
	}

	override void viewport(IVec2 location, IVec2 size) {
		glViewport(location.x, location.y, size.x, size.y);
	}

	override void colorWriteMask(bool r, bool g, bool b, bool a) {
		glColorMask(r, g, b, a);
	}

	override void draw(DrawMode mode, Shader shader, Mesh mesh, size_t startVertex, size_t numVertices) {
		if (!cast(OpenGLMesh) mesh) {
			throw new OpenGLException("Cannot draw non-OpenGL mesh in OpenGL context");
		}

		if (!cast(OpenGLShader) shader) {
			throw new OpenGLException("Cannot use non-OpenGL shader in OpenGL context");
		}

		OpenGLShader glShader = cast(OpenGLShader) shader;

		glShader.useShader();

		foreach (i, texture; glShader.textures) {
			glActiveTexture(GL_TEXTURE0 + cast(int) i);
			if (cast(OpenGLFramebuffer) texture) {
				glBindTexture(GL_TEXTURE_2D, (cast(OpenGLFramebuffer) texture).texColorBuffer);
			}
			else if (cast(OpenGLTexture) texture) {
				glBindTexture(GL_TEXTURE_2D, (cast(OpenGLTexture) texture).texture);
			}
			else {
				glBindTexture(GL_TEXTURE_2D, 0);
			}
		}

		glBindVertexArray((cast(OpenGLMesh) mesh).vao);

		GLenum glMode;
		final switch (mode) {
		case DrawMode.Triangles:
			glMode = GL_TRIANGLES;
			break;
		case DrawMode.TriangleFan:
			glMode = GL_TRIANGLE_FAN;
			break;
		case DrawMode.TriangleStrip:
			glMode = GL_TRIANGLE_STRIP;
			break;
		}

		glDrawArrays(glMode, cast(GLint) startVertex, cast(GLsizei) numVertices);
	}

}
