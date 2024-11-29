module main

import os
import time
import strconv
import db.sqlite
import term
import term.ui
import rand

@[table: 'reminders']
struct Reminder {
	id           int @[primary; sql: serial]
	created_time ?time.Time
	delisted     ?bool
	name         string
}

fn store_reminder(db_addr string, name string)! {
	db := sqlite.connect(db_addr)!

	sql db {
		create table Reminder
	}!

	new_reminder := Reminder{ name: name created_time: time.now() }

	sql db {
		insert new_reminder into Reminder
	}!

	println("stored reminder \"${name}\"")
}

fn remove_reminder(db_addr string, id int)! {
	db := sqlite.connect(db_addr)!
	sql db {
		update Reminder set delisted = true where id == id
	}!
}

fn list_reminders(db_addr string)! {
	db := sqlite.connect(db_addr)!

	all_reminders := sql db {
		select from Reminder where delisted is none || delisted == false
	}!

	emoji    := random_emoji()
	fg_color := random_color()
	header := "${emoji} Reminders ${emoji}"
	println(term.bold(term.rgb(fg_color.r, fg_color.g, fg_color.b, header)))
	for reminder in all_reminders {
		mut msg := "[${reminder.id}] - ${reminder.name}"
		msg = term.rgb(fg_color.r, fg_color.g, fg_color.b, msg)
		// msg = term.slow_blink(msg)
		println(msg)
	}
}

fn exec_args(db_addr string, args []string)! {
	if args.len == 0 { return error("no arguments provided") }

	match args[0] {
		"symlink" {
			link_path := os.expand_tilde_to_home("~/bin/bn")
			me := os.executable()
			println("attempting to symlink '${me}'")
			os.rm(link_path) or {}
			os.symlink(me, link_path) or {
				return error("failed to symlink to ${link_path}: ${err}")
			}
			println("successfully symlinked to ${link_path}")
		}

		"init" {
			db := sqlite.connect(db_addr)!
			sql db {
				create table Reminder
			}!
		}

		"add" {
			if args.len < 2 { return error("missing name of type 'reminder' to add") }
			match args[1] {
				"reminder" {
					if args.len < 3 { return error("missing reminder description") }
					store_reminder(db_addr, args[2])!
				}
				else { return error("unknown type '${args[1]}' to add") }
			}
		}

		"remove" {
			if args.len < 2 { return error("missing name of type 'reminder' to remove") }
			match args[1] {
				"reminder" {
					if args.len < 3 { return error("missing reminder id") }
					reminder_id := strconv.atoi(args[2]) or { return error("${args[2]} is not a valid integer") }
					remove_reminder(db_addr, reminder_id)!
				}
				else { return error("unknown type '${args[1]}' to remove") }
			}
		}

		"list" {
			if args.len < 2 { return error("missing name of type 'reminders' or 'notifications' to list") }
			match args[1] {
				"reminders" {
					list_reminders(db_addr)!
				}
				else { return error("unknown type '${args[1]}' to list") }
			}
		}
		else { return error("unknown command '${args[0]}'") }
	}
}

const fg_pallette = [
	ui.Color{ r: 252, g: 186, b: 3 }
	ui.Color{ r: 232, g: 50, b: 14 }
	ui.Color{ r: 200, g: 90, b: 100 }
	ui.Color{ r: 14, g: 232, b: 36 }
	ui.Color{ r: 19, g: 215, b: 240 }
]

const emoji_pallette = [
	"⚠️", "🚨", "🛎️", "👾", "👏", "💥"
]

fn random_color() ui.Color {
	return randomly_choose_color(get_date_as_unix(fn () time.Time { return time.now() }))
}

fn random_emoji() string {
	return randomly_choose_emoji(get_date_as_unix(fn () time.Time { return time.now() }))
}

fn randomly_choose_color(seed int) ui.Color {
	rand.seed([u32(seed), 2485544])
	index := rand.intn(fg_pallette.len) or { 0 }
	return fg_pallette[index]
}

fn randomly_choose_emoji(seed int) string {
	rand.seed([u32(seed), 33883])
	index := rand.intn(emoji_pallette.len) or { 0 }
	return emoji_pallette[index]
}

fn get_date_as_unix(time_now fn () time.Time) int {
	now := time_now()
	date := time.Time{
		year: now.year
		month: now.month
		day: now.day
	}
	return int(date.unix())
}

fn main() {
	db_addr := os.join_path("${os.dir(os.executable())}", "bubbles.db")
	exec_args(db_addr, os.args[1..]) or {
		eprintln("something went wrong: ${err}")
		exit(1)
	}
}
