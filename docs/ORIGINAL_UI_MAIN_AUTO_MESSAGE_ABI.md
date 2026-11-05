# Original main auto-combat message

MainScene memberSHA80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f
Project14564 references UI/Main/Hud_AutoMessage.csb,
SHA25684d976b87d030d8fdd8edee3bffe17d697486eb7f991e096257c26f9dc3993a1.
The original project position is600.5,235.5; root76 and Text124 keep their
original transforms, alpha/color/font. Text124 is exactly '자동 전투 중'.

`source_main_auto_message_bindings.gd` consumes only the existing
hud.get_parent().player.auto_enabled boolean. It binds original root76 visible
state and the original static Text124. Missing/invalid actor state is unavailable,
not a fabricated false value. `source_main_hud.gd` mounts it through the actual
MainScene14564 parent, updates it on existing combat refresh and observes the
same actor state for changes. No attack/auto-hunt/effect/save logic is added.

The actual source Text124 is position0, anchor0.5, scale1, visible1 and alpha255;
its color remains the source value. No extra alpha/position/width or timer is
chosen. Original Fx_Loop clip5..95 is metadata only: source repeat/autoplay is
undeclared, so this connection does not call play/seek/loop. It is a static
source message while the real auto flag is enabled, not completed source
animation behavior.

This dedicated component is not a replacement for the general show_message
string or its existing2.6-second timer. Main/HUD's held other direct message
components have particular PVP/dungeon/link/observe/hell/event/area/boss roles;
they are not assigned arbitrary general message text. The original generic
message component/role relation remains missing.

The current smaller v7 source scope does not include this member. A later
combined pack must actually include Text124's original scene/dependencies.
No new test, game execution, render, audit or CI has been performed.
