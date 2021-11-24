import std.stdio;
import std.datetime;
import arsd.simpledisplay;
import canvas;
import canvas.backend.common;
import canvas : Color;

void main() {
	setOpenGLContextVersion(3, 3);
	openGLContextCompatible = false;

	SimpleWindow win = new SimpleWindow(640, 480, "Example", OpenGlOptions.yes, Resizability.allowResizing);

	CanvasRenderingContext context;
	Canvas canvas;
	Material material;

	win.visibleForTheFirstTime = {
		win.setAsCurrentOpenGlContext;

		context = new CanvasRenderingContext({});
		canvas = new Canvas(context, IVec2(320, 200));
		material = canvas.createMaterial(`
			vec4 mainImage(vec2 coord) {
				return vec4(coord, coord.x + coord.y, 1.0);
			}
		`);
	};

	double frames = 0;
	double start = MonoTime.currTime.ticks / cast(double) MonoTime.ticksPerSecond;

	win.redrawOpenGlScene = {
		try {
			frames += 1;
			if (frames % 60 == 0) {
				double now = MonoTime.currTime.ticks / cast(double) MonoTime.ticksPerSecond;
				double secs = now - start;
				writeln(frames / secs);
				frames = 0;
				start = now;
			}

			canvas.size = IVec2(win.width, win.height);

			canvas.clear(Color(1, 1, 1));

			Vec2 random() {
				import std.random : uniform;

				return Vec2(
					uniform!"[]"(0.0, cast(double) win.width),
					uniform!"[]"(0.0, cast(double) win.height),
				);
			}

			Path path;
			path.moveTo(random);
			foreach (i; 0 .. 50) {
				path.lineTo(random);
			}
			path.close();

			FillOptions options;
			options.antialias = Antialias.Subpixel;
			options.fillRule = FillRule.NonZero;
			options.tint = Color(1, 1, 1);
			options.material = material;
			canvas.fill(path, options);

			blitToScreen(canvas, canvas.size);
		}
		catch (Exception e) {
			writeln(e);
		}
	};

	win.vsync = false;

	win.eventLoop(1, delegate {
		win.redrawOpenGlSceneNow;
	});
}
