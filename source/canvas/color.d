module canvas.color;

enum BlendingMode {
	Normal,
	Overwrite,
	Add,
}

struct Color {

	double r = 0, g = 0, b = 0, a = 0;

	this(double r, double g, double b, double a = 1.0) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

}
