module canvas.path;
import canvas.math;

alias Path = AbstractPath!double;
alias FPath = AbstractPath!float;

enum PathCommand {
	Move,
	Line,
	QuadCurve,
	CubicCurve,
	Close,
}

struct AbstractPath(T) {
	immutable(AbstractVec2!T)[] values;
	immutable(PathCommand)[] commands;

	this(V)(AbstractPath!V base) {
		foreach (v; base.values) {
			values ~= AbstractVec2!T(v);
		}
		commands = base.commands;
	}

	void moveTo(AbstractVec2!T point) {
		values ~= point;
		commands ~= PathCommand.Move;
	}

	void lineTo(AbstractVec2!T point) {
		values ~= point;
		commands ~= PathCommand.Line;
	}

	void curveTo(AbstractVec2!T control, AbstractVec2!T point) {
		values ~= [control, point];
		commands ~= PathCommand.QuadCurve;
	}

	void curveTo(AbstractVec2!T control1, AbstractVec2!T control2, AbstractVec2!T point) {
		values ~= [control1, control2, point];
		commands ~= PathCommand.CubicCurve;
	}

	void close() {
		commands ~= PathCommand.Close;
	}

	auto opBinary(string op)(const(AbstractPath!T) rhs) const if (op == "~") {
		Path result;
		result.values = values ~ rhs.values;
		result.commands = commands ~ rhs.commands;
		return result;
	}

	auto opOpAssign(string op, T)(T value) {
		this = mixin("this" ~ op ~ "value");
		return this;
	}

	AbstractPath!T flatten() {
		AbstractPath!T newPath;

		AbstractVec2!T lastPoint, lastMove;
		size_t pointIndex;
		foreach (cmd; commands) {
			final switch (cmd) {
			case PathCommand.Move:
				auto point = values[pointIndex++];
				newPath.moveTo(point);
				lastMove = point;
				lastPoint = point;
				break;
			case PathCommand.Close:
				newPath.close();
				lastPoint = lastMove;
				break;
			case PathCommand.Line:
				auto point = values[pointIndex++];
				newPath.lineTo(point);
				lastPoint = point;
				break;
			case PathCommand.QuadCurve:
				auto start = lastPoint;
				auto control = values[pointIndex++];
				auto point = values[pointIndex++];
				AbstractVec2!T compute(T alpha) {
					auto p1 = start * (1 - alpha) + control * alpha;
					auto p2 = control * (1 - alpha) + point * alpha;
					auto q = p1 * (1 - alpha) + p2 * alpha;
					return q;
				}
				foreach (i; 0 .. 8) {
					auto alpha = (i + 1) / 8.0;
					auto q = compute(alpha);
					newPath.lineTo(q);
					lastPoint = q;
				}
				break;
			case PathCommand.CubicCurve:
				assert(0);
			}
		}
		
		return newPath;
	}

	// TODO: this seems to break in some cases; try stroking some text to see
	AbstractPath!T stroke(T distanceOutward, T distanceInward) {
		AbstractPath!T newPath;

		size_t pointIndex;
		AbstractVec2!T[] points;

		void removeDuplicatePoints() {
			while (points.length > 0 && points[0].eq(points[$ - 1], 1e-7)) {
				points = points[0 .. $ - 1];
			}
		}

		void finishClosedPath() {
			removeDuplicatePoints();

			if (points.length < 2) {
				return;
			}

			foreach (j; 0 .. 2) {
				import std.range : iota;
				import std.math : PI;

				foreach (i; 0 .. points.length) {
					int factor = j == 0 ? 1 : -1;
					auto a = points[(cast(int)(i + 0) * factor + cast(int)(2 * points.length)) % cast(int) points.length];
					auto b = points[(cast(int)(i + 1) * factor + cast(int)(2 * points.length)) % cast(int) points.length];
					auto c = points[(cast(int)(i + 2) * factor + cast(int)(2 * points.length)) % cast(int) points.length];
					auto normalAB = (AbstractMat3!T.rotation(PI / 2) * (b - a)).normalize;
					auto normalBC = (AbstractMat3!T.rotation(PI / 2) * (c - b)).normalize;
					auto distance = j == 0 ? distanceOutward : distanceInward;
					auto a2 = a + normalAB * distance;
					auto ab = b + normalAB * distance;
					auto bc = b + normalBC * distance;
					auto c2 = c + normalBC * distance;

					// we wanna find the intersection of r(t) = (a2 + (ab - a2) * t) and r(s) = (c2 + (bc - c2) * s)

					AbstractVec2!T A, B, C, D;
					A = a2;
					B = ab - a2;
					C = c2;
					D = bc - c2;

					T s = (B.x * A.y + C.x * B.y - A.x * B.y - B.x * C.y) / (B.x * D.y - D.x * B.y);
					AbstractVec2!T intersection = C + D * s;

					if (i == 0) {
						newPath.moveTo(intersection);
					}
					else {
						newPath.lineTo(intersection);
					}
				}

				newPath.close();
			}

			points = [];
		}

		void finishOpenPath() {
			if (points.length < 2) {
				return;
			}

			foreach (j; 0 .. 2) {
				import std.range : iota;
				import std.math : PI;

				if (j == 0) {
					auto a = points[0];
					auto b = points[1];
					auto normal = (AbstractMat3!T.rotation(PI / 2) * (b - a)).normalize;
					auto a2 = a + normal * distanceOutward;

					newPath.moveTo(a2);
				}
				else {
					auto a = points[$ - 1];
					auto b = points[$ - 2];
					auto normal = (AbstractMat3!T.rotation(PI / 2) * (b - a)).normalize;
					auto a2 = a + normal * distanceInward;

					newPath.lineTo(a2);
				}

				foreach (i; (j == 0 ? 0 : 1) .. points.length - (j == 0 ? 2 : 1)) {
					int factor = j == 0 ? 1 : -1;
					auto a = points[(cast(int)(i + 0) * factor + cast(int)(2 * points.length)) % cast(int) points.length];
					auto b = points[(cast(int)(i + 1) * factor + cast(int)(2 * points.length)) % cast(int) points.length];
					auto c = points[(cast(int)(i + 2) * factor + cast(int)(2 * points.length)) % cast(int) points.length];
					auto normalAB = (AbstractMat3!T.rotation(PI / 2) * (b - a)).normalize;
					auto normalBC = (AbstractMat3!T.rotation(PI / 2) * (c - b)).normalize;
					auto distance = j == 0 ? distanceOutward : distanceInward;
					auto a2 = a + normalAB * distance;
					auto ab = b + normalAB * distance;
					auto bc = b + normalBC * distance;
					auto c2 = c + normalBC * distance;

					// we wanna find the intersection of r(t) = (a2 + (ab - a2) * t) and r(s) = (c2 + (bc - c2) * s)

					AbstractVec2!T A, B, C, D;
					A = a2;
					B = ab - a2;
					C = c2;
					D = bc - c2;

					T s = (B.x * A.y + C.x * B.y - A.x * B.y - B.x * C.y) / (B.x * D.y - D.x * B.y);
					AbstractVec2!T intersection = C + D * s;

					newPath.lineTo(intersection);
				}

				if (j == 0) {
					auto a = points[$ - 1];
					auto b = points[$ - 2];
					auto normal = (AbstractMat3!T.rotation(PI / 2) * (b - a)).normalize;
					auto a2 = a - normal * distanceOutward;

					newPath.lineTo(a2);
				}
				else {
					auto a = points[0];
					auto b = points[1];
					auto normal = (AbstractMat3!T.rotation(PI / 2) * (b - a)).normalize;
					auto a2 = a - normal * distanceInward;

					newPath.lineTo(a2);
				}
			}

			newPath.close();

			points = [];
		}

		AbstractVec2!T lastPoint;

		foreach (cmd; commands) {
			final switch (cmd) {
			case PathCommand.Move:
				auto point = values[pointIndex++];
				finishOpenPath();
				points ~= point;
				lastPoint = point;
				break;
			case PathCommand.Close:
				finishClosedPath();
				break;
			case PathCommand.Line:
				auto point = values[pointIndex++];
				if (!point.eq(lastPoint, 1e-7)) {
					points ~= point;
					lastPoint = point;
				}
				break;
			case PathCommand.QuadCurve:
			case PathCommand.CubicCurve:
				assert(0);
			}
		}

		finishOpenPath();

		return newPath;
	}

	AbstractPath!T stroke(double width) {
		return stroke(width / 2, width / 2);
	}

	static AbstractPath!T rectangle(AbstractVec2!T position, AbstractVec2!T size) {
		AbstractPath!T result;
		result.moveTo(position);
		result.lineTo(position + AbstractVec2!T(0, size.y));
		result.lineTo(position + size);
		result.lineTo(position + AbstractVec2!T(size.x, 0));
		result.close();
		return result;
	}

}
