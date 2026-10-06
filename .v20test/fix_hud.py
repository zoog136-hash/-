from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
text = "\n".join(line for line in text.splitlines() if "icon_max_width" not in line) + "\n"
text = text.replace("var exp: ProgressBar = ProgressBar.new()", "var experience_bar: ProgressBar = ProgressBar.new()")
text = text.replace("exp.custom_minimum_size = Vector2(226.0, 11.0)", "experience_bar.custom_minimum_size = Vector2(226.0, 11.0)")
text = text.replace("exp.show_percentage = false", "experience_bar.show_percentage = false")
text = text.replace('exp.add_theme_stylebox_override("background", _bar_background())', 'experience_bar.add_theme_stylebox_override("background", _bar_background())')
text = text.replace('exp.add_theme_stylebox_override("fill", _bar_fill(Color(0.95, 0.60, 0.12, 1.0)))', 'experience_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.95, 0.60, 0.12, 1.0)))')
text = text.replace("exp_box.add_child(exp)", "exp_box.add_child(experience_bar)")
text = text.replace("exp_bar = exp", "exp_bar = experience_bar")
p.write_text(text, encoding="utf-8")
