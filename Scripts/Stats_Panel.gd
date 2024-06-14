extends Panel

@onready var stats_label : Label = $"Stats Label"


func update_stats(new_stats_string):
	stats_label.text = new_stats_string
