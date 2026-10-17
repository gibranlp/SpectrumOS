#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include "virtual-keyboard.h"

static struct wl_display *display;
static struct wl_seat *seat;
static struct zwp_virtual_keyboard_manager_v1 *manager;
static struct zwp_virtual_keyboard_v1 *keyboard;
static volatile sig_atomic_t stopping;
static uint32_t pressed;

static void shutdown_signal(int number) { (void)number; stopping = 1; }
static uint32_t timestamp(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (uint32_t)((uint64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000);
}
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, "wl_seat") && !seat)
        seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
    else if (!strcmp(interface, "zwp_virtual_keyboard_manager_v1") && !manager)
        manager = wl_registry_bind(registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener listener = { global, removed };

/* El mapa completo conserva los códigos físicos y se comparte entre todas las reglas. */
static int lookup(struct xkb_keymap *map, const char *name, uint32_t *code, uint32_t *mods) {
    xkb_keysym_t symbol = xkb_keysym_from_name(name, XKB_KEYSYM_NO_FLAGS);
    if (!symbol) return -1;
    for (xkb_keycode_t key = xkb_keymap_min_keycode(map); key <= xkb_keymap_max_keycode(map); key++) {
        for (xkb_level_index_t level = 0; level < 2; level++) {
            const xkb_keysym_t *symbols;
            int count = xkb_keymap_key_get_syms_by_level(map, key, 0, level, &symbols);
            for (int index = 0; index < count; index++) {
                if (symbols[index] != symbol || key < 8) continue;
                *code = key - 8;
                xkb_mod_index_t shift = xkb_keymap_mod_get_index(map, XKB_MOD_NAME_SHIFT);
                if (level && (shift == XKB_MOD_INVALID || shift >= 32)) return -1;
                *mods = level ? 1u << shift : 0;
                return 0;
            }
        }
    }
    return -1;
}
int main(int argc, char **argv) {
    int result = 1;
    struct xkb_context *context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    const struct xkb_rule_names names = { .layout = "us" };
    struct xkb_keymap *map = context ? xkb_keymap_new_from_names(context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS) : NULL;
    if (!map) goto finish;
    if (argc == 3 && !strcmp(argv[1], "--check-key")) {
        uint32_t code, mods;
        if (lookup(map, argv[2], &code, &mods) == 0) {
            printf("%u %u\n", code, mods); result = 0;
        }
        goto finish;
    }
    if (argc != 1) goto finish;
    struct sigaction action = { .sa_handler = shutdown_signal };
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL); sigaction(SIGINT, &action, NULL);
    signal(SIGPIPE, SIG_IGN);
    display = wl_display_connect(NULL);
    if (!display) goto finish;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !seat || !manager) goto finish;
    keyboard = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager, seat);
    char *text = xkb_keymap_get_as_string(map, XKB_KEYMAP_FORMAT_TEXT_V1);
    if (!text) goto finish;
    size_t size = strlen(text) + 1;
    int fd = memfd_create("spectrum-hotkey-map", MFD_CLOEXEC);
    if (fd < 0 || write(fd, text, size) != (ssize_t)size) {
        free(text); if (fd >= 0) close(fd); goto finish;
    }
    free(text);
    zwp_virtual_keyboard_v1_keymap(keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, (uint32_t)size);
    if (wl_display_roundtrip(display) < 0) { close(fd); goto finish; }
    close(fd);
    char line[64];
    result = 0;
    while (!stopping && fgets(line, sizeof(line), stdin)) {
        char *newline = strchr(line, '\n');
        if (!newline || strncmp(line, "press ", 6)) { result = 1; break; }
        *newline = '\0';
        uint32_t code, mods;
        if (lookup(map, line + 6, &code, &mods)) { puts("error"); fflush(stdout); continue; }
        zwp_virtual_keyboard_v1_modifiers(keyboard, mods, 0, 0, 0);
        zwp_virtual_keyboard_v1_key(keyboard, timestamp(), code, WL_KEYBOARD_KEY_STATE_PRESSED);
        pressed = code;
        if (wl_display_flush(display) < 0) { result = 1; break; }
        usleep(5000);
        zwp_virtual_keyboard_v1_key(keyboard, timestamp(), code, WL_KEYBOARD_KEY_STATE_RELEASED);
        pressed = 0;
        zwp_virtual_keyboard_v1_modifiers(keyboard, 0, 0, 0, 0);
        if (wl_display_roundtrip(display) < 0) { result = 1; break; }
        puts("ok"); fflush(stdout);
    }
finish:
    if (keyboard) {
        if (pressed) zwp_virtual_keyboard_v1_key(keyboard, timestamp(), pressed, WL_KEYBOARD_KEY_STATE_RELEASED);
        zwp_virtual_keyboard_v1_modifiers(keyboard, 0, 0, 0, 0);
        zwp_virtual_keyboard_v1_destroy(keyboard);
        wl_display_flush(display);
    }
    if (display) wl_display_disconnect(display);
    if (map) xkb_keymap_unref(map);
    if (context) xkb_context_unref(context);
    return result;
}
