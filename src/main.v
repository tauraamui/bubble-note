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

fn store_reminder(db_addr string, name string)! {
	db := sqlite.connect(db_addr)!

	sql db {
		create table Reminder
	}!

	new_reminder := Reminder{ id: int(db.last_insert_rowid() + 1) name: name created_time: time.now() }

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

	for reminder in all_reminders {
		println("[${reminder.id}] - ${reminder.name}")
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

fn main() {
	db_addr := os.join_path("${os.dir(os.executable())}", "bubbles.db")
	exec_args(db_addr, os.args[1..]) or {
		eprintln("something went wrong: ${err}")
		exit(1)
	}
}
