/* Give each Claude Desktop profile its own window app id on Linux.
 *
 * Electron sets CHROME_DESKTOP from package.json ("com.anthropic.Claude.desktop")
 * at start. It makes the Wayland app_id and the X11 WM_CLASS from that value, so
 * all profiles share one id and the dock puts all windows under one icon.
 * The --class flag does not change this.
 *
 * Load this library with LD_PRELOAD and set CLAUDE_APP_ID=claude-desktop-N.
 * Then getenv("CHROME_DESKTOP") returns "claude-desktop-N.desktop".
 * The library keeps LD_PRELOAD and CLAUDE_APP_ID in the environment. A restart from
 * inside the app (for example after an update) then keeps the same app id.
 * Child processes (shells, git, tools) load the library, but it does nothing
 * there: it is active only when /proc/self/exe is the Claude binary.
 *
 * Build: gcc -O2 -shared -fPIC -DCLAUDE_EXE='"<path of the Claude executable>"' \
 *            -o claude-app-id.so claude-app-id.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef CLAUDE_EXE
#define CLAUDE_EXE "/usr/lib/claude-desktop/claude-desktop"
#endif

static char desktop[256];
static char *(*real_getenv)(const char *);

static char *call_real(const char *name) {
    if (!real_getenv)
        real_getenv = (char *(*)(const char *))dlsym(RTLD_NEXT, "getenv");
    return real_getenv ? real_getenv(name) : NULL;
}

__attribute__((constructor)) static void claude_app_id_init(void) {
    /* A wrapper such as setsid or bash also loads this library. Do nothing there,
       so the variables reach the Claude process. */
    char exe[PATH_MAX];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    if (n <= 0)
        return;
    exe[n] = 0;
    if (strcmp(exe, CLAUDE_EXE) != 0)
        return;
    const char *id = call_real("CLAUDE_APP_ID");
    if (id && *id && strlen(id) + sizeof(".desktop") <= sizeof(desktop)) {
        strcpy(desktop, id);
        strcat(desktop, ".desktop");
    }
}

char *getenv(const char *name) {
    if (desktop[0] && strcmp(name, "CHROME_DESKTOP") == 0)
        return desktop;
    return call_real(name);
}
