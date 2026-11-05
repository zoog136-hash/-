extends "res://tests/title523_main_test.gd"
func rank_fixture(count: int) -> void:
 # Isolated prefix fixture, never a production grant or natural progression claim.
 world.titles.state=world.titles.fresh(); world.titles.state.last_clock=world.titles.now()
 for i: int in count: world.titles.state.achieved.append(int(world.titles.source.stages[i].id))
func run() -> void:
 root.size=Vector2i(1280,720); root.gui_embed_subwindows=true
 world=load("res://Main.tscn").instantiate(); root.add_child(world)
 world.set_process(false); world.save_timer=-100000
 check(QA.enter_game(world),"personal real Main class confirmation")
 world.player.set_physics_process(false); world.field_population.set_process(false)
 await frames(5)
 var t=world.titles
 if "--verify-reload" in OS.get_cmdline_user_args():
  check(t.source.problem.is_empty() and not t.blocked,"personal new-process original source valid")
  check(t.state.achieved.size()==20 and t.personal.data(t.state).names==["◇Z"],"personal20stage and stored name restored")
  check(t.display_name()=="◇Z" and world.title_badge.text=="◇Z" and world.title_badge.visible,"personal actor badge restored")
  check(world.title_badge.get_theme_color("font_color").is_equal_approx(Color("#ffde00")),"personal ColorTable412 yellow restored")
  check(world.gold==174321 and world.quest_service.quests.size()==10,"personal wallet and existing10quests preserved")
  await finish(); return
 world.hud.open_titles523(); await frames()
 if not t.source.problem.is_empty():
  await tap(view().find_child("InstallTitle523",true,false),view())
  for child: Node in view().get_children():
   if child is FileDialog: child.file_selected.emit(OS.get_environment("TWILIGHT_TITLE523_ZIP")); break
  await frames()
 check(t.source.problem.is_empty(),"personal UI installs verified owner source")
 rank_fixture(12); world.level=85; world.gold=174321
 view().build(); await frames(8); await tap(view().find_child("OpenPersonalTitle",true,false),view())
 check(view().find_child("PersonalName",true,false)==null,"personal UI locked before BaronI")
 rank_fixture(13); view().build(); await frames(8)
 if not view().personal_box.visible: await tap(view().find_child("OpenPersonalTitle",true,false),view())
 await shot("title-personal-unlocked")
 if not view().personal_box.visible:
  check(false,"personal editor must open by pointer"); await finish(); return
 check(view().personal_box.visible and view().personal_color.item_count==8,"personal editor and all8 choices visible")
 check(not view().personal_color.is_item_disabled(0) and view().personal_color.is_item_disabled(1),"personal color locks displayed")
 check(world._save_game(true)==OK,"personal baseline real atomic save")
 var baseline:=FileAccess.get_sha256(world.save_path())
 view().personal_text.text="◇Z"
 world.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary) -> Error:
  writer_failures+=1; return ERR_CANT_CREATE
 await tap(view().find_child("SavePersonalName",true,false),view())
 check(writer_failures==1 and view().personal_notice.text.contains("저장 실패"),"personal real UI reaches failed writer")
 check(view().personal_text.text=="◇Z" and t.personal.data(t.state).names.is_empty() and FileAccess.get_sha256(world.save_path())==baseline,"personal failed write keeps draft state and exact file")
 world.equipment_collections.test_save_writer=Callable()
 await tap(view().find_child("SavePersonalName",true,false),view())
 check(t.personal.data(t.state).names==["◇Z"],"personal pointer stores actual name")
 await tap(view().find_child("ApplyPersonalName",true,false),view())
 check(t.display_name()=="◇Z" and world.title_badge.text=="◇Z","personal pointer activates actor badge")
 check(world.title_badge.get_theme_color("font_color").is_equal_approx(Color("#7f7f7f")),"first source color preserved gray")
 await tap(view().find_child("DeletePersonalName",true,false),view())
 check(t.personal.data(t.state).names.size()==1 and view().personal_notice.text.contains("2초"),"personal UI cooldown refuses active deletion")
 await create_timer(2.1).timeout
 await tap(view().find_child("DeletePersonalName",true,false),view())
 check(t.personal.data(t.state).names.is_empty() and t.display_name()==t.current_name(),"personal pointer delete restores highest")
 view().personal_text.text="◇Z"
 await tap(view().find_child("SavePersonalName",true,false),view())
 # Independently verify later color threshold through real editor; retained
 # prefix fixture is clearly not a natural map supply/progression assertion.
 var owned: Dictionary=t.state.duplicate(true)
 rank_fixture(20); t.state.personal=owned.personal.duplicate(true); t.state.revision=int(owned.revision)+1
 view().build(); await frames()
 check(not view().personal_color.is_item_disabled(6),"yellow unlock at actual source threshold")
 view().personal_color.select(6); view().preview_personal()
 check(view().personal_preview.get_theme_color("font_color").is_equal_approx(Color("#ffde00")),"editor preview uses ColorTable namespace")
 await create_timer(2.1).timeout
 await tap(view().find_child("ApplyPersonalName",true,false),view())
 check(t.display_name()=="◇Z" and t.personal.data(t.state).color_rule==62,"yellow selection commits source rule62")
 check(world.title_badge.get_theme_color("font_color").is_equal_approx(Color("#ffde00")),"real actor badge yellow")
 var totals: Dictionary=t.totals().duplicate(true)
 await tap(view().find_child("ToggleTitleDisplay",true,false),view())
 check(not world.title_badge.visible and t.totals()==totals,"hide personal badge leaves benefits once")
 await tap(view().find_child("ToggleTitleDisplay",true,false),view())
 check(world.title_badge.visible and t.totals()==totals,"show personal badge leaves benefits once")
 var d:=data()
 check(d.title523.personal.names==["◇Z"] and int(d.title523.personal.color_rule)==62 and d.gold==174321,"actual atomic save owns name color wallet")
 await shot("title-personal-editor")
 root.size=Vector2i(854,480); world.hud.open_titles523(); await frames(8)
 await tap(view().find_child("OpenPersonalTitle",true,false),view())
 view().ensure_control_visible(view().personal_text); await frames()
 check(view().personal_text.size.x<=854 and view().personal_box.visible,"personal small-screen editor fits")
 await shot("title-personal-small-854")
 await finish()
