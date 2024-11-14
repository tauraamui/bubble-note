module main

import os
import time
import strconv
import db.sqlite

@[table: 'reminders']
struct Reminder {
	id           int @[primary; serial]
	created_time ?time.Time
	delisted     ?bool
	name         string
}

fn store_reminder(name string)! {
	db := sqlite.connect('bubbles.db')!

	sql db {
		create table Reminder
	}!

	new_reminder := Reminder{ name: name created_time: time.now() }

	sql db {
		insert new_reminder into Reminder
	}!

	println("stored reminder \"${name}\"")
}

fn remove_reminder(id int)! {
	db := sqlite.connect('bubbles.db')!
	sql db {
		update Reminder set delisted = true where id == id
	}!
}

fn list_reminders()! {
	db := sqlite.connect('bubbles.db')!

	all_reminders := sql db {
		select from Reminder where delisted is none || delisted == false
	}!

	for reminder in all_reminders {
		println("[${reminder.id}] - ${reminder.name}")
	}
}

fn exec_args(args []string)! {
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
			db := sqlite.connect('bubbles.db')!
			sql db {
				create table Reminder
			}!
		}

		"add" {
			if args.len < 2 { return error("missing name of type 'reminder' to add") }
			match args[1] {
				"reminder" {
					if args.len < 3 { return error("missing reminder description") }
					store_reminder(args[2])!
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
					remove_reminder(reminder_id)!
				}
				else { return error("unknown type '${args[1]}' to remove") }
			}
		}

		"list" {
			if args.len < 2 { return error("missing name of type 'reminders' or 'notifications' to list") }
			match args[1] {
				"reminders" {
					list_reminders()!
				}
				else { return error("unknown type '${args[1]}' to list") }
			}
		}
		else { return error("unknown command '${args[0]}'") }
	}
}

fn main() {
	exec_args(os.args[1..]) or {
		eprintln("something went wrong: ${err}")
		exit(1)
	}
}
