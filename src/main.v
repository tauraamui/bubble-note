module main

import os
import time
import strconv
import db.sqlite
import db.pg
import orm
import term
import term.ui
import rand
import json

struct Config {
pub mut:
	db_local bool
	db_host string
	db_port int
	db_user string
	db_pass string
	db_name string
}

fn resolve_config() Config {
	mut cfg := Config{ db_local: true }
	config_file_content := os.read_file("./bubble.config") or { return cfg }
	parsed_config := json.decode(Config, config_file_content) or { return cfg }
	return parsed_config
}

@[table: 'reminders']
struct Reminder {
	id           int @[primary; sql: serial]
	created_time ?time.Time
	delisted     ?bool
	name         string
}

fn local_db_path() !string {
	local_db_parent_dir := os.join_path(os.data_dir(), "bubble-note")
	os.mkdir(local_db_parent_dir) or {}
	return os.join_path(local_db_parent_dir, "bubble.db")
}

fn connect_sqlite() !orm.Connection {
	db_path := local_db_path()!
	db := sqlite.connect(db_path)!
	return orm.Connection(db)
}

fn connect_postgres(cfg Config) !orm.Connection {
	return pg.connect(pg.Config{
		host: "ep-silent-river-a269hxda.eu-central-1.aws.neon.tech"
		port: 5432
		user: "notes_owner"
		password: "NIkSYKGue2z5"
		dbname: "notes"
	})!
}

fn store_reminder(cfg Config, name string)! {
	db := if cfg.db_local { connect_sqlite()! } else { connect_postgres(cfg)! }
	// db := sqlite.connect(db_addr)!
	// db := connect_postgres(db_addr)!

	sql db {
		create table Reminder
	}!

	new_reminder := Reminder{ name: name created_time: time.now() }

	sql db {
		insert new_reminder into Reminder
	}!

	println("stored reminder \"${name}\"")
}

fn remove_reminder(cfg Config, id int)! {
	db := if cfg.db_local { connect_sqlite()! } else { connect_postgres(cfg)! }
	// db := sqlite.connect(db_addr)!
	// db := connect_postgres(db_addr)!
	// db := sqlite.connect(db_addr)!
	sql db {
		update Reminder set delisted = true where id == id
	}!
}

fn list_reminders(cfg Config)! {
	db := if cfg.db_local { connect_sqlite()! } else { connect_postgres(cfg)! }
	// db := sqlite.connect(db_addr)!
	// db := connect_postgres(db_addr)!
	// db := sqlite.connect(db_addr)!

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
			cfg := resolve_config()!
			db := if cfg.db_local { connect_sqlite()! } else { connect_postgres(cfg)! }
			location := if cfg.db_local { local_db_path()! } else { cfg.db_host }
			println("setting up db @ ${location}")
			// db := sqlite.connect(db_addr)!
			// db := connect_postgres(db_addr)!
			sql db {
				create table Reminder
			}!
		}

		"add" {
			cfg := resolve_config()!
			if args.len < 2 { return error("missing name of type 'reminder' to add") }
			match args[1] {
				"reminder" {
					if args.len < 3 { return error("missing reminder description") }
					store_reminder(cfg, args[2])!
				}
				else { return error("unknown type '${args[1]}' to add") }
			}
		}

		"remove" {
			cfg := resolve_config()!
			if args.len < 2 { return error("missing name of type 'reminder' to remove") }
			match args[1] {
				"reminder" {
					if args.len < 3 { return error("missing reminder id") }
					reminder_id := strconv.atoi(args[2]) or { return error("${args[2]} is not a valid integer") }
					remove_reminder(cfg, reminder_id)!
				}
				else { return error("unknown type '${args[1]}' to remove") }
			}
		}

		"list" {
			cfg := resolve_config()!
			if args.len < 2 { return error("missing name of type 'reminders' or 'notifications' to list") }
			match args[1] {
				"reminders" {
					list_reminders(cfg)!
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
