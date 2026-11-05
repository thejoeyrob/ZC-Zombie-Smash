#pragma once
// A small libretro frontend for Godot: loads one emulator core (a libretro .so), runs a game in it, and hands the picture, sound and saves to GDScript.
// Only one core is active at a time (libretro callbacks carry no user pointer, so the active instance is kept in a global).

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>
#include <vector>

#include "libretro.h"

namespace godot {

class RetroCore : public RefCounted {
	GDCLASS(RetroCore, RefCounted)

protected:
	static void _bind_methods();

public:
	RetroCore();
	~RetroCore();

	bool load_core(const String &p_path);
	bool load_game(const String &p_rom_path, const String &p_system_dir, const String &p_save_dir);
	void unload();
	void run();
	void reset();

	int get_width() const { return width; }
	int get_height() const { return height; }
	double get_fps() const { return fps; }
	double get_sample_rate() const { return sample_rate; }
	double get_aspect() const { return aspect; }
	String get_core_name() const { return core_name; }
	String get_last_error() const { return last_error; }
	bool is_loaded() const { return game_loaded; }

	PackedByteArray get_frame() const { return frame; }
	bool take_frame_ready();
	PackedVector2Array take_audio();
	void set_pad(int p_port, int p_mask);

	PackedByteArray get_save_ram();
	void set_save_ram(const PackedByteArray &p_data);
	PackedByteArray save_state();
	bool load_state(const PackedByteArray &p_data);

	// libretro callbacks (static trampolines call these on the active instance)
	bool on_environment(unsigned cmd, void *data);
	void on_video(const void *data, unsigned w, unsigned h, size_t pitch);
	size_t on_audio_batch(const int16_t *data, size_t frames);
	void on_audio_sample(int16_t l, int16_t r);
	int16_t on_input(unsigned port, unsigned device, unsigned index, unsigned id);

private:
	void *lib = nullptr;
	String core_name;
	String last_error;
	String system_dir_utf8;
	String save_dir_utf8;
	CharString system_dir_c;
	CharString save_dir_c;

	void (*fn_set_environment)(retro_environment_t) = nullptr;
	void (*fn_set_video_refresh)(retro_video_refresh_t) = nullptr;
	void (*fn_set_audio_sample)(retro_audio_sample_t) = nullptr;
	void (*fn_set_audio_sample_batch)(retro_audio_sample_batch_t) = nullptr;
	void (*fn_set_input_poll)(retro_input_poll_t) = nullptr;
	void (*fn_set_input_state)(retro_input_state_t) = nullptr;
	void (*fn_init)() = nullptr;
	void (*fn_deinit)() = nullptr;
	unsigned (*fn_api_version)() = nullptr;
	void (*fn_get_system_info)(struct retro_system_info *) = nullptr;
	void (*fn_get_system_av_info)(struct retro_system_av_info *) = nullptr;
	void (*fn_reset)() = nullptr;
	void (*fn_run)() = nullptr;
	size_t (*fn_serialize_size)() = nullptr;
	bool (*fn_serialize)(void *, size_t) = nullptr;
	bool (*fn_unserialize)(const void *, size_t) = nullptr;
	bool (*fn_load_game)(const struct retro_game_info *) = nullptr;
	void (*fn_unload_game)() = nullptr;
	void *(*fn_get_memory_data)(unsigned) = nullptr;
	size_t (*fn_get_memory_size)(unsigned) = nullptr;

	bool core_inited = false;
	bool game_loaded = false;
	bool need_fullpath = false;
	std::vector<uint8_t> rom_data;
	CharString rom_path_c;

	unsigned pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
	int width = 0;
	int height = 0;
	double fps = 60.0;
	double sample_rate = 44100.0;
	double aspect = 4.0 / 3.0;
	bool frame_ready = false;
	PackedByteArray frame;
	std::vector<float> audio;
	int pads[2] = { 0, 0 };

	bool resolve(const char *name, void **out);
};

} // namespace godot
