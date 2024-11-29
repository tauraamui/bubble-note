module main

import time
import term.ui

const test_today_timestamp = 1732841321

fn test_randomly_choosing_color_from_date_seed() {
	today := fn () time.Time {
		return time.unix(test_today_timestamp)
	}

	yesterday := fn () time.Time {
		return time.unix(test_today_timestamp - 86_400)
	}

	today_unix := get_date_as_unix(today)
	yesterday_unix := get_date_as_unix(yesterday)

	assert today_unix != yesterday_unix

	todays_color := randomly_choose_color(today_unix)
	yesterdays_color := randomly_choose_color(yesterday_unix)

	assert todays_color != yesterdays_color

	assert yesterdays_color == ui.Color{
		r: 19,
		g: 215,
		b: 240
	}

	assert todays_color == ui.Color{
		r: 200,
		g: 90,
		b: 100
	}
}

