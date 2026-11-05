#include "retro_core.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <dlfcn.h>
#include <cstdarg>
#include <cstdio>
#include <cstring>

using namespace godot;

static RetroCore *g_active = nullptr;

// ---- libretro C callbacks -------------------------------------------------------------------------------------
static bool cb_environment(unsigned cmd, void *data) {
	return g_active ? g_active->on_environment(cmd, data) : false;
}
static void cb_video(const void *data, unsigned w, unsigned h, size_t pitch) {
	if (g_active) {
		g_active->on_video(data, w, h, pitch);
	}
}
static size_t cb_audio_batch(const int16_t *data, size_t frames) {
	return g_active ? g_active->on_audio_batch(data, frames) : frames;
}
static void cb_audio_sample(int16_t l, int16_t r) {
	if (g_active) {
		g_active->on_audio_sample(l, r);
	}
}
static void cb_input_poll() {}
static int16_t cb_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
	return g_active ? g_active->on_input(port, device, index, id) : 0;
}
static void cb_log(enum retro_log_level level, const char *fmt, ...) {
	// cores log a lot; only keep errors out of the way of the game
	if (level < RETRO_LOG_ERROR) {
		return;
	}
	char buf[512];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	UtilityFunctions::print("[retro core] ", String::utf8(buf));
}

// ---- class ----------------------------------------------------------------------------------------------------
void RetroCore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_core", "path"), &RetroCore::load_core);
	ClassDB::bind_method(D_METHOD("load_game", "rom_path", "system_dir", "save_dir"), &RetroCore::load_game);
	ClassDB::bind_method(D_METHOD("unload"), &RetroCore::unload);
	ClassDB::bind_method(D_METHOD("run"), &RetroCore::run);
	ClassDB::bind_method(D_METHOD("reset"), &RetroCore::reset);
	ClassDB::bind_method(D_METHOD("get_width"), &RetroCore::get_width);
	ClassDB::bind_method(D_METHOD("get_height"), &RetroCore::get_height);
	ClassDB::bind_method(D_METHOD("get_fps"), &RetroCore::get_fps);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &RetroCore::get_sample_rate);
	ClassDB::bind_method(D_METHOD("get_aspect"), &RetroCore::get_aspect);
	ClassDB::bind_method(D_METHOD("get_core_name"), &RetroCore::get_core_name);
	ClassDB::bind_method(D_METHOD("get_last_error"), &RetroCore::get_last_error);
	ClassDB::bind_method(D_METHOD("is_loaded"), &RetroCore::is_loaded);
	ClassDB::bind_method(D_METHOD("get_frame"), &RetroCore::get_frame);
	ClassDB::bind_method(D_METHOD("take_frame_ready"), &RetroCore::take_frame_ready);
	ClassDB::bind_method(D_METHOD("take_audio"), &RetroCore::take_audio);
	ClassDB::bind_method(D_METHOD("set_pad", "port", "mask"), &RetroCore::set_pad);
	ClassDB::bind_method(D_METHOD("get_save_ram"), &RetroCore::get_save_ram);
	ClassDB::bind_method(D_METHOD("set_save_ram", "data"), &RetroCore::set_save_ram);
	ClassDB::bind_method(D_METHOD("save_state"), &RetroCore::save_state);
	ClassDB::bind_method(D_METHOD("load_state", "data"), &RetroCore::load_state);
}

RetroCore::RetroCore() {}

RetroCore::~RetroCore() {
	unload();
}

bool RetroCore::resolve(const char *name, void **out) {
	*out = dlsym(lib, name);
	if (*out == nullptr) {
		last_error = String("core is missing ") + String(name);
		return false;
	}
	return true;
}

bool RetroCore::load_core(const String &p_path) {
	unload();
	last_error = "";
	CharString path = p_path.utf8();
	lib = dlopen(path.get_data(), RTLD_NOW | RTLD_LOCAL);
	if (lib == nullptr) {
		const char *e = dlerror();
		last_error = String("cannot load ") + p_path + String(": ") + String::utf8(e ? e : "unknown");
		return false;
	}
	bool ok = true;
	ok &= resolve("retro_set_environment", (void **)&fn_set_environment);
	ok &= resolve("retro_set_video_refresh", (void **)&fn_set_video_refresh);
	ok &= resolve("retro_set_audio_sample", (void **)&fn_set_audio_sample);
	ok &= resolve("retro_set_audio_sample_batch", (void **)&fn_set_audio_sample_batch);
	ok &= resolve("retro_set_input_poll", (void **)&fn_set_input_poll);
	ok &= resolve("retro_set_input_state", (void **)&fn_set_input_state);
	ok &= resolve("retro_init", (void **)&fn_init);
	ok &= resolve("retro_deinit", (void **)&fn_deinit);
	ok &= resolve("retro_api_version", (void **)&fn_api_version);
	ok &= resolve("retro_get_system_info", (void **)&fn_get_system_info);
	ok &= resolve("retro_get_system_av_info", (void **)&fn_get_system_av_info);
	ok &= resolve("retro_reset", (void **)&fn_reset);
	ok &= resolve("retro_run", (void **)&fn_run);
	ok &= resolve("retro_serialize_size", (void **)&fn_serialize_size);
	ok &= resolve("retro_serialize", (void **)&fn_serialize);
	ok &= resolve("retro_unserialize", (void **)&fn_unserialize);
	ok &= resolve("retro_load_game", (void **)&fn_load_game);
	ok &= resolve("retro_unload_game", (void **)&fn_unload_game);
	ok &= resolve("retro_get_memory_data", (void **)&fn_get_memory_data);
	ok &= resolve("retro_get_memory_size", (void **)&fn_get_memory_size);
	if (!ok) {
		dlclose(lib);
		lib = nullptr;
		return false;
	}
	if (fn_api_version() != RETRO_API_VERSION) {
		last_error = "core uses a different libretro version";
		dlclose(lib);
		lib = nullptr;
		return false;
	}
	struct retro_system_info info;
	memset(&info, 0, sizeof(info));
	fn_get_system_info(&info);
	core_name = String::utf8(info.library_name ? info.library_name : "core");
	need_fullpath = info.need_fullpath;
	g_active = this;
	fn_set_environment(cb_environment);
	fn_init();
	core_inited = true;
	fn_set_video_refresh(cb_video);
	fn_set_audio_sample(cb_audio_sample);
	fn_set_audio_sample_batch(cb_audio_batch);
	fn_set_input_poll(cb_input_poll);
	fn_set_input_state(cb_input_state);
	return true;
}

bool RetroCore::load_game(const String &p_rom_path, const String &p_system_dir, const String &p_save_dir) {
	if (lib == nullptr) {
		last_error = "no core loaded";
		return false;
	}
	g_active = this;
	system_dir_c = p_system_dir.utf8();
	save_dir_c = p_save_dir.utf8();
	rom_path_c = p_rom_path.utf8();
	rom_data.clear();
	struct retro_game_info game;
	memset(&game, 0, sizeof(game));
	game.path = rom_path_c.get_data();
	if (!need_fullpath) {
		FILE *f = fopen(rom_path_c.get_data(), "rb");
		if (f == nullptr) {
			last_error = String("cannot open ") + p_rom_path;
			return false;
		}
		fseek(f, 0, SEEK_END);
		long len = ftell(f);
		fseek(f, 0, SEEK_SET);
		if (len <= 0 || len > 256L * 1024 * 1024) {
			fclose(f);
			last_error = "game file has a strange size";
			return false;
		}
		rom_data.resize((size_t)len);
		size_t got = fread(rom_data.data(), 1, (size_t)len, f);
		fclose(f);
		if (got != (size_t)len) {
			last_error = "could not read the game file";
			return false;
		}
		game.data = rom_data.data();
		game.size = rom_data.size();
	}
	pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
	if (!fn_load_game(&game)) {
		last_error = "the core did not accept this game";
		return false;
	}
	game_loaded = true;
	struct retro_system_av_info av;
	memset(&av, 0, sizeof(av));
	fn_get_system_av_info(&av);
	fps = av.timing.fps > 1.0 ? av.timing.fps : 60.0;
	sample_rate = av.timing.sample_rate > 1000.0 ? av.timing.sample_rate : 44100.0;
	width = (int)av.geometry.base_width;
	height = (int)av.geometry.base_height;
	aspect = av.geometry.aspect_ratio > 0.1f ? av.geometry.aspect_ratio : (height > 0 ? (double)width / (double)height : 4.0 / 3.0);
	audio.clear();
	frame_ready = false;
	return true;
}

void RetroCore::unload() {
	if (g_active == this) {
		if (game_loaded && fn_unload_game) {
			fn_unload_game();
		}
		if (core_inited && fn_deinit) {
			fn_deinit();
		}
	}
	game_loaded = false;
	core_inited = false;
	if (lib != nullptr) {
		dlclose(lib);
		lib = nullptr;
	}
	if (g_active == this) {
		g_active = nullptr;
	}
	rom_data.clear();
	audio.clear();
}

void RetroCore::run() {
	if (!game_loaded || fn_run == nullptr) {
		return;
	}
	g_active = this;
	fn_run();
}

void RetroCore::reset() {
	if (game_loaded && fn_reset) {
		g_active = this;
		fn_reset();
	}
}

bool RetroCore::take_frame_ready() {
	bool r = frame_ready;
	frame_ready = false;
	return r;
}

PackedVector2Array RetroCore::take_audio() {
	PackedVector2Array out;
	size_t n = audio.size() / 2;
	if (n == 0) {
		return out;
	}
	out.resize((int64_t)n);
	Vector2 *w = out.ptrw();
	for (size_t i = 0; i < n; i++) {
		w[i] = Vector2(audio[i * 2], audio[i * 2 + 1]);
	}
	audio.clear();
	return out;
}

void RetroCore::set_pad(int p_port, int p_mask) {
	if (p_port >= 0 && p_port < 2) {
		pads[p_port] = p_mask;
	}
}

PackedByteArray RetroCore::get_save_ram() {
	PackedByteArray out;
	if (!game_loaded || !fn_get_memory_size || !fn_get_memory_data) {
		return out;
	}
	size_t n = fn_get_memory_size(RETRO_MEMORY_SAVE_RAM);
	void *p = fn_get_memory_data(RETRO_MEMORY_SAVE_RAM);
	if (n == 0 || p == nullptr) {
		return out;
	}
	out.resize((int64_t)n);
	memcpy(out.ptrw(), p, n);
	return out;
}

void RetroCore::set_save_ram(const PackedByteArray &p_data) {
	if (!game_loaded || !fn_get_memory_size || !fn_get_memory_data) {
		return;
	}
	size_t n = fn_get_memory_size(RETRO_MEMORY_SAVE_RAM);
	void *p = fn_get_memory_data(RETRO_MEMORY_SAVE_RAM);
	if (n == 0 || p == nullptr) {
		return;
	}
	size_t m = (size_t)p_data.size() < n ? (size_t)p_data.size() : n;
	memcpy(p, p_data.ptr(), m);
}

PackedByteArray RetroCore::save_state() {
	PackedByteArray out;
	if (!game_loaded || !fn_serialize_size) {
		return out;
	}
	size_t n = fn_serialize_size();
	if (n == 0) {
		return out;
	}
	out.resize((int64_t)n);
	if (!fn_serialize(out.ptrw(), n)) {
		out.clear();
	}
	return out;
}

bool RetroCore::load_state(const PackedByteArray &p_data) {
	if (!game_loaded || !fn_unserialize || p_data.size() == 0) {
		return false;
	}
	g_active = this;
	return fn_unserialize(p_data.ptr(), (size_t)p_data.size());
}

// ---- callbacks ------------------------------------------------------------------------------------------------
bool RetroCore::on_environment(unsigned cmd, void *data) {
	switch (cmd) {
		case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
			pixel_format = *(const unsigned *)data;
			return pixel_format <= RETRO_PIXEL_FORMAT_RGB565;
		case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
			*(const char **)data = system_dir_c.get_data();
			return true;
		case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
			*(const char **)data = save_dir_c.get_data();
			return true;
		case RETRO_ENVIRONMENT_GET_CAN_DUPE:
			*(bool *)data = true;
			return true;
		case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
			struct retro_log_callback *l = (struct retro_log_callback *)data;
			l->log = cb_log;
			return true;
		}
		case RETRO_ENVIRONMENT_GET_VARIABLE:
			return false; // every core option keeps its default
		case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
			*(bool *)data = false;
			return true;
		case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
			*(unsigned *)data = 0;
			return true;
		case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
			return true;
		case RETRO_ENVIRONMENT_SET_ROTATION:
		case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
		case RETRO_ENVIRONMENT_SET_VARIABLES:
		case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
		case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
		case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
		case RETRO_ENVIRONMENT_SET_GEOMETRY:
		case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
		case RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE:
		case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS:
		case RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK:
			return true;
		case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: {
			const struct retro_system_av_info *av = (const struct retro_system_av_info *)data;
			if (av->timing.fps > 1.0) {
				fps = av->timing.fps;
			}
			if (av->timing.sample_rate > 1000.0) {
				sample_rate = av->timing.sample_rate;
			}
			return true;
		}
		default:
			return false;
	}
}

void RetroCore::on_video(const void *data, unsigned w, unsigned h, size_t pitch) {
	if (data == nullptr || w == 0 || h == 0) {
		return; // a repeated frame: keep showing the last one
	}
	if (w != (unsigned)width || h != (unsigned)height || frame.size() != (int64_t)w * h * 4) {
		width = (int)w;
		height = (int)h;
		frame.resize((int64_t)w * h * 4);
	}
	uint8_t *dst = frame.ptrw();
	const uint8_t *src = (const uint8_t *)data;
	for (unsigned y = 0; y < h; y++) {
		const uint8_t *row = src + y * pitch;
		uint8_t *out = dst + (size_t)y * w * 4;
		if (pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) {
			for (unsigned x = 0; x < w; x++) {
				out[x * 4 + 0] = row[x * 4 + 2];
				out[x * 4 + 1] = row[x * 4 + 1];
				out[x * 4 + 2] = row[x * 4 + 0];
				out[x * 4 + 3] = 255;
			}
		} else if (pixel_format == RETRO_PIXEL_FORMAT_RGB565) {
			const uint16_t *p = (const uint16_t *)row;
			for (unsigned x = 0; x < w; x++) {
				uint16_t v = p[x];
				uint8_t r = (v >> 11) & 31, g = (v >> 5) & 63, b = v & 31;
				out[x * 4 + 0] = (r << 3) | (r >> 2);
				out[x * 4 + 1] = (g << 2) | (g >> 4);
				out[x * 4 + 2] = (b << 3) | (b >> 2);
				out[x * 4 + 3] = 255;
			}
		} else { // 0RGB1555
			const uint16_t *p = (const uint16_t *)row;
			for (unsigned x = 0; x < w; x++) {
				uint16_t v = p[x];
				uint8_t r = (v >> 10) & 31, g = (v >> 5) & 31, b = v & 31;
				out[x * 4 + 0] = (r << 3) | (r >> 2);
				out[x * 4 + 1] = (g << 3) | (g >> 2);
				out[x * 4 + 2] = (b << 3) | (b >> 2);
				out[x * 4 + 3] = 255;
			}
		}
	}
	frame_ready = true;
}

size_t RetroCore::on_audio_batch(const int16_t *data, size_t frames) {
	if (audio.size() > (size_t)sample_rate * 2) {
		return frames; // far behind: drop rather than grow without bound
	}
	size_t old = audio.size();
	audio.resize(old + frames * 2);
	for (size_t i = 0; i < frames * 2; i++) {
		audio[old + i] = (float)data[i] / 32768.0f;
	}
	return frames;
}

void RetroCore::on_audio_sample(int16_t l, int16_t r) {
	audio.push_back((float)l / 32768.0f);
	audio.push_back((float)r / 32768.0f);
}

int16_t RetroCore::on_input(unsigned port, unsigned device, unsigned index, unsigned id) {
	(void)index;
	if (device != RETRO_DEVICE_JOYPAD || port > 1) {
		return 0;
	}
	if (id == RETRO_DEVICE_ID_JOYPAD_MASK) {
		return (int16_t)pads[port];
	}
	return (pads[port] >> id) & 1;
}
