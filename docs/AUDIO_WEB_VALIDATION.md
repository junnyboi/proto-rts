# Audio Web Validation

**Date:** 2 September 2026

**Build:** Final reconciled single-threaded Godot Web export

**Bundle:** 49 MB total; 11 MB PCK

The final bundle loaded from a cache-busted local HTTP URL after integrating the expanded HUD, cursor, and persistent-command commits. Godot 4.7.1 initialized through Emscripten 4.0.20 and WebGL 2.0, and the title screen rendered on the browser canvas. The PCK inspection gate confirmed all 25 runtime audio paths and excluded review captures and HUD concept art.

Fresh probes were installed around `AudioContext.prototype.resume()` and `AudioBufferSourceNode.prototype.start()` before interaction. At baseline there were zero resume calls and zero source starts. A JavaScript-dispatched Start Game event advanced to faction selection and attempted playback while the context was still suspended, as expected because synthetic events are not trusted autoplay gestures.

A browser-tool pointer gesture invoked Godot's audio resume path. Four queued resume calls resolved, and the context transitioned from **`suspended`** to **`running`**. A measured Celestial command gesture then entered a live **Celestial Court vs Demon Host** skirmish. The expanded economy ribbon rendered the complete **AUDIO ON M** control.

Pressing `Q` selected three workers. The Web Audio source counter increased from one to three: two new sources started while the context was `running`, covering the faction/UI confirmation and live unit-selection cue path. The browser console contained the expected Godot, WebGL, and Emscripten initialization logs and no fatal Godot, WebAssembly, resource, or Web Audio errors.

**Result:** pass. The final browser build unlocks audio after a real gesture, preserves the score path across title and active gameplay, and plays generated interaction SFX through Godot Web Sample audio.
