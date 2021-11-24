module canvas.math;
import std.traits;

// Vectors:

alias Vec2 = AbstractVec2!double;
alias IVec2 = AbstractVec2!int;
alias FVec2 = AbstractVec2!float;
alias RVec2 = AbstractVec2!real;

alias Vec3 = AbstractVec3!double;
alias IVec3 = AbstractVec3!int;
alias FVec3 = AbstractVec3!float;
alias RVec3 = AbstractVec3!real;

alias Vec4 = AbstractVec4!double;
alias IVec4 = AbstractVec4!int;
alias FVec4 = AbstractVec4!float;
alias RVec4 = AbstractVec4!real;

struct AbstractVec2(T) {
	T x = 0;
	T y = 0;

	this(V)(AbstractVec2!V base) {
		x = cast(T) base.x;
		y = cast(T) base.y;
	}

	this(T x, T y = 0) {
		this.x = x;
		this.y = y;
	}

	T magnitudeSq() @property const {
		return x * x + y * y;
	}

	static if (isFloatingPoint!T) {
		T magnitude() @property const {
			import std.math : sqrt;

			return sqrt(x * x + y * y);
		}

		AbstractVec2!T normalize() const {
			if (magnitude == 0) {
				return this;
			}

			return this / magnitude;
		}

		AbstractVec2!T round() const {
			import std.math : round;

			return AbstractVec2!T(round(x), round(y));
		}
	}

	auto opBinary(string op, R)(const(AbstractVec2!R) rhs) const {
		alias ResT = typeof(mixin("cast(T) 0" ~ op ~ "cast(R) 0"));
		AbstractVec2!ResT result;
		result.x = mixin("x" ~ op ~ "rhs.x");
		result.y = mixin("y" ~ op ~ "rhs.y");
		return result;
	}

	auto opBinary(string op, R)(const(R) rhs) const if (isNumeric!R) {
		alias ResT = typeof(mixin("cast(T) 0" ~ op ~ "cast(R) 0"));
		AbstractVec2!ResT result;
		result.x = mixin("x" ~ op ~ "rhs");
		result.y = mixin("y" ~ op ~ "rhs");
		return result;
	}

	auto opOpAssign(string op, T)(T value) {
		auto res = mixin("this" ~ op ~ "value");
		x = res.x;
		y = res.y;
		return this;
	}

	auto opUnary(string op)() const if (op == "-") {
		return AbstractVec2!T(-x, -y);
	}

	AbstractVec2!T opDispatch(string member)() @property const
	if (member.length == 2) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'x' && c <= 'y'));

		AbstractVec2!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	AbstractVec3!T opDispatch(string member)() @property const
	if (member.length == 3) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'x' && c <= 'y'));

		AbstractVec3!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	AbstractVec4!T opDispatch(string member)() @property const
	if (member.length == 4) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'x' && c <= 'y'));

		AbstractVec4!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	bool eq(AbstractVec2!T other, T eps) const {
		return (this - other).magnitudeSq <= eps * eps;
	}

	string toString() const @safe {
		import std.conv : text;
	
		return text("(", x, ", ", y, ")");
	}
}

struct AbstractVec3(T) {
	T x = 0;
	T y = 0;
	T z = 0;

	this(V)(AbstractVec3!V base) {
		x = cast(T) base.x;
		y = cast(T) base.y;
		z = cast(T) base.z;
	}

	this(T x, T y = 0, T z = 0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	T magnitudeSq() @property const {
		return x * x + y * y + z * z;
	}

	static if (isFloatingPoint!T) {
		T magnitude() @property const {
			import std.math : sqrt;

			return sqrt(x * x + y * y + z * z);
		}

		AbstractVec3!T normalize() const {
			if (magnitude == 0) {
				return this;
			}

			return this / magnitude;
		}
	}

	auto opBinary(string op, R)(const(AbstractVec3!R) rhs) const {
		alias ResT = typeof(mixin("cast(T) 0" ~ op ~ "cast(R) 0"));
		AbstractVec3!ResT result;
		result.x = mixin("x" ~ op ~ "rhs.x");
		result.y = mixin("y" ~ op ~ "rhs.y");
		result.z = mixin("z" ~ op ~ "rhs.z");
		return result;
	}

	auto opBinary(string op, R)(const(R) rhs) const if (isNumeric!R) {
		alias ResT = typeof(mixin("cast(T) 0" ~ op ~ "cast(R) 0"));
		AbstractVec3!ResT result;
		result.x = mixin("x" ~ op ~ "rhs");
		result.y = mixin("y" ~ op ~ "rhs");
		result.z = mixin("z" ~ op ~ "rhs");
		return result;
	}

	auto opOpAssign(string op, T)(T value) {
		auto res = mixin("this" ~ op ~ "value");
		x = res.x;
		y = res.y;
		z = res.z;
		return this;
	}

	auto opUnary(string op)() const if (op == "-") {
		return AbstractVec3!T(-x, -y, -z);
	}

	AbstractVec2!T opDispatch(string member)() @property const
	if (member.length == 2) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'x' && c <= 'z'));

		AbstractVec2!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	AbstractVec3!T opDispatch(string member)() @property const
	if (member.length == 3) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'x' && c <= 'z'));

		AbstractVec3!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	AbstractVec4!T opDispatch(string member)() @property const
	if (member.length == 4) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'x' && c <= 'z'));

		AbstractVec4!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	bool eq(AbstractVec3!T other, T eps) const {
		return (this - other).magnitudeSq <= eps * eps;
	}

	string toString() const @safe {
		import std.conv : text;
	
		return text("(", x, ", ", y, ", ", z, ")");
	}
}

struct AbstractVec4(T) {
	T x = 0;
	T y = 0;
	T z = 0;
	T w = 0;

	ref inout(T) r() inout @property { return x; }
	ref inout(T) g() inout @property { return y; }
	ref inout(T) b() inout @property { return z; }
	ref inout(T) a() inout @property { return w; }

	this(V)(AbstractVec4!V base) {
		x = cast(T) base.x;
		y = cast(T) base.y;
		z = cast(T) base.z;
		w = cast(T) base.w;
	}

	this(T x, T y = 0, T z = 0, T w = 0) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	T magnitudeSq() @property const {
		return x * x + y * y + z * z + w * w;
	}

	static if (isFloatingPoint!T) {
		T magnitude() @property const {
			import std.math : sqrt;

			return sqrt(x * x + y * y + z * z + w * w);
		}

		AbstractVec4!T normalize() const {
			if (magnitude == 0) {
				return this;
			}

			return this / magnitude;
		}
	}

	auto opBinary(string op, R)(const(AbstractVec4!R) rhs) const {
		alias ResT = typeof(mixin("cast(T) 0" ~ op ~ "cast(R) 0"));
		AbstractVec4!ResT result;
		result.x = mixin("x" ~ op ~ "rhs.x");
		result.y = mixin("y" ~ op ~ "rhs.y");
		result.z = mixin("z" ~ op ~ "rhs.z");
		result.w = mixin("w" ~ op ~ "rhs.w");
		return result;
	}

	auto opBinary(string op, R)(const(R) rhs) const if (isNumeric!R) {
		alias ResT = typeof(mixin("cast(T) 0" ~ op ~ "cast(R) 0"));
		AbstractVec4!ResT result;
		result.x = mixin("x" ~ op ~ "rhs");
		result.y = mixin("y" ~ op ~ "rhs");
		result.z = mixin("z" ~ op ~ "rhs");
		result.w = mixin("w" ~ op ~ "rhs");
		return result;
	}

	auto opOpAssign(string op, T)(T value) {
		auto res = mixin("this" ~ op ~ "value");
		x = res.x;
		y = res.y;
		z = res.z;
		w = res.w;
		return this;
	}

	auto opUnary(string op)() const if (op == "-") {
		return AbstractVec4!T(-x, -y, -z, -w);
	}

	AbstractVec2!T opDispatch(string member)() @property const
	if (member.length == 2) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'w' && c <= 'z'));

		AbstractVec2!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	AbstractVec3!T opDispatch(string member)() @property const
	if (member.length == 3) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'w' && c <= 'z'));

		AbstractVec3!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	AbstractVec4!T opDispatch(string member)() @property const
	if (member.length == 4) {
		import std.algorithm : all;

		static assert(member.all!(c => c >= 'w' && c <= 'z'));

		AbstractVec4!T result;
		static foreach (i, char c; member) {
			result.tupleof[i] = mixin("this." ~ c);
		}
		return result;
	}

	bool eq(AbstractVec4!T other, T eps) const {
		return (this - other).magnitudeSq <= eps * eps;
	}

	string toString() const @safe {
		import std.conv : text;

		return text("(", x, ", ", y, ", ", z, ", ", w, ")");
	}
}

// Matrices:

alias Mat3 = AbstractMat3!double;
alias IMat3 = AbstractMat3!int;
alias FMat3 = AbstractMat3!float;
alias RMat3 = AbstractMat3!real;

// alias Mat4 = AbstractMat4!double;
// alias IMat4 = AbstractMat4!int;
// alias FMat4 = AbstractMat4!float;
// alias RMat4 = AbstractMat4!real;

struct AbstractMat3(T) {
	private T[3][3] m = [
		[1, 0, 0],
		[0, 1, 0],
		[0, 0, 1],
	];

	this(T x, T y = 0) {
		m = [
			[1, 0, x],
			[0, 1, y],
			[0, 0, cast(T) 1],
		];
	}

	this(AbstractVec2!T vec) {
		m = [
			[1, 0, vec.x],
			[0, 1, vec.y],
			[0, 0, cast(T) 1],
		];
	}

	this(T[3][3] values) {
		m = values;
	}

	this(V)(AbstractMat3!V value) {
		foreach (i; 0 .. 3) {
			foreach (j; 0 .. 3) {
				m[i][j] = cast(T) value.m[i][j];
			}
		}
	}

	T opIndex(size_t r, size_t c) const { return m[r][c]; }

	T x() const @property { return m[0][2]; }
	T y() const @property { return m[1][2]; }

	AbstractVec2!T translation() const {
		return AbstractVec2!T(x, y);
	}

	AbstractMat3!T withTranslation(AbstractVec2!T value) const {
		AbstractMat3!T res = this;
		res.m[0][2] = value.x;
		res.m[1][2] = value.y;
		return res;
	}

	AbstractMat3!T withoutTranslation() const {
		return withTranslation(AbstractVec2!T.init);
	}

	AbstractVec2!T scale() const {
		return AbstractVec2!T(m[0][0], m[1][1]);
	}

	static AbstractMat3!T scale(AbstractVec2!T value) {
		return AbstractMat3!T().withScale(value);
	}

	static AbstractMat3!T scale(T value) {
		return AbstractMat3!T().withScale(value);
	}

	AbstractMat3!T withScale(AbstractVec2!T value) const {
		AbstractMat3!T res = this;
		res.m[0][0] = value.x;
		res.m[1][1] = value.y;
		return res;
	}

	AbstractMat3!T withScale(T value) const {
		AbstractMat3!T res = this;
		res.m[0][0] = value;
		res.m[1][1] = value;
		return res;
	}

	AbstractMat3!T withoutScale() const {
		return withScale(1);
	}

	static if (isFloatingPoint!T) {
		static AbstractMat3!T rotation(double theta) {
			import std.math : cos, sin;

			return AbstractMat3!T([
				[cast(T) cos(theta), cast(T) -sin(theta), 0],
				[cast(T) sin(theta), cast(T) cos(theta), 0],
				[0, 0, cast(T) 1],
			]);
		}
	}

	AbstractVec2!T opBinary(string op)(AbstractVec2!T other) const if (op == "*") {
		return (this * AbstractMat3!T(other)).translation;
	}

	AbstractMat3!T opBinary(string op)(AbstractMat3!T other) const if (op == "*") {
		AbstractMat3!T res;

		res.m[0][0] = other.m[0][0] * m[0][0] + other.m[1][0] * m[0][1] + other.m[2][0] * m[0][2];
		res.m[1][0] = other.m[0][0] * m[1][0] + other.m[1][0] * m[1][1] + other.m[2][0] * m[1][2];
		res.m[2][0] = other.m[0][0] * m[2][0] + other.m[1][0] * m[2][1] + other.m[2][0] * m[2][2];
		res.m[0][1] = other.m[0][1] * m[0][0] + other.m[1][1] * m[0][1] + other.m[2][1] * m[0][2];
		res.m[1][1] = other.m[0][1] * m[1][0] + other.m[1][1] * m[1][1] + other.m[2][1] * m[1][2];
		res.m[2][1] = other.m[0][1] * m[2][0] + other.m[1][1] * m[2][1] + other.m[2][1] * m[2][2];
		res.m[0][2] = other.m[0][2] * m[0][0] + other.m[1][2] * m[0][1] + other.m[2][2] * m[0][2];
		res.m[1][2] = other.m[0][2] * m[1][0] + other.m[1][2] * m[1][1] + other.m[2][2] * m[1][2];
		res.m[2][2] = other.m[0][2] * m[2][0] + other.m[1][2] * m[2][1] + other.m[2][2] * m[2][2];

		return res;
	}
}
