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
import lib.ansii

struct Config {
pub mut:
	db_local bool
	db_host string @[json: "host"]
	db_port int @[json: "port"]
	db_user string @[json: "user"]
	db_pass string @[json: "password"]
	db_name string @[json: "dbname"]
}

fn resolve_config() !Config {
	mut cfg := Config{ db_local: true }
	cfg_dir := os.config_dir()!
	cfg_file_path := os.join_path(cfg_dir, "bubble-note", "bubble.config")
	config_file_content := os.read_file(cfg_file_path) or { return cfg }
	parsed_config := json.decode(Config, config_file_content) or { return cfg }
	return parsed_config
}

@[table: 'reminders']
struct Reminder {
	id            int @[primary; sql: serial]
	uuid          string
	created_time  ?time.Time
	delisted      ?bool
	name          string
}

fn resolve_local_db_path() string {
	db_file_name := "bubbles.db"
	data_dir := os.data_dir()
	data_bubble_dir := os.join_path(data_dir, "bubble-note")
	os.mkdir(data_bubble_dir) or {}
	return os.join_path(data_bubble_dir, db_file_name)
}

fn connect_sqlite(path string) !orm.Connection {
	db := sqlite.connect(path)!
	return orm.Connection(db)
}

fn connect_postgres(cfg Config) !orm.Connection {
	db := pg.connect(pg.Config{
		host: cfg.db_host
		port: cfg.db_port
		user: cfg.db_user
		password: cfg.db_pass
		dbname: cfg.db_name
	})!
	return db
}

fn store_reminder(cfg Config, db orm.Connection, uuid fn () string, name string)! {
	// db := if cfg.db_local { connect_sqlite(resolve_local_db_path())! } else { connect_postgres(cfg)! }
	// db := connect_sqlite(resolve_local_db_path())!

	sql db {
		create table Reminder
	}!

	new_reminder := Reminder{ uuid: uuid(), name: name created_time: time.now() }

	sql db {
		insert new_reminder into Reminder
	}!

	println("stored reminder \"${name}\"")
}

fn sync_to_remote(cfg Config)! {
	local_db  := connect_sqlite(resolve_local_db_path())!
	remote_db := connect_postgres(cfg)!

	local_reminders := sql local_db {
		select from Reminder
	}!

	remote_reminders := sql remote_db {
		select from Reminder
	}!

	local_uuids  := local_reminders.map(it.uuid)
	remote_uuids := remote_reminders.map(it.uuid)

	shared_reminders := local_reminders.filter(remote_uuids.contains(it.uuid))
	for reminder in shared_reminders {
		remote_reminder := remote_reminders[remote_uuids.index(reminder.uuid)]
		local_delisted := reminder.delisted or { false }
		remote_delisted := remote_reminder.delisted or { false }

		if local_delisted == remote_delisted { continue }

		if local_delisted {
			remove_reminder_id(cfg, remote_db, remote_reminder.id)!
			continue
		}

		if remote_delisted {
			remove_reminder_id(cfg, local_db, reminder.id)!
			continue
		}
	}

	for reminder in local_reminders.filter(!remote_uuids.contains(it.uuid)) {
		if reminder.delisted or { false } { continue }
		store_reminder(cfg, remote_db, fn [reminder] () string { return reminder.uuid }, reminder.name)!
	}

	for reminder in remote_reminders.filter(!local_uuids.contains(it.uuid)) {
		if reminder.delisted or { false } { continue }
		store_reminder(cfg, local_db, fn [reminder] () string { return reminder.uuid }, reminder.name )!
	}
}

fn remove_reminder_id(cfg Config, db orm.Connection, id int)! {
	// db := if cfg.db_local { connect_sqlite(resolve_local_db_path())! } else { connect_postgres(cfg)! }
	// db := connect_sqlite(resolve_local_db_path())!
	sql db {
		update Reminder set delisted = true where id == id
	}!
}

fn remove_reminder_ulid(cfg Config, ulid string)! {
	// db := if cfg.db_local { connect_sqlite(resolve_local_db_path())! } else { connect_postgres(cfg)! }
	db := connect_sqlite(resolve_local_db_path())!
	ulid_pattern := "%${ulid.to_upper_ascii()}"
	sql db {
		update Reminder set delisted = true where (delisted is none || delisted == false) && uuid like "${ulid_pattern}"
	}!
}

fn list_reminders(cfg Config)! {
	// db := if cfg.db_local { connect_sqlite(resolve_local_db_path())! } else { connect_postgres(cfg)! }
	db := connect_sqlite(resolve_local_db_path())!

	all_reminders := sql db {
		select from Reminder where delisted is none || delisted == false
	}!

	emoji    := random_emoji()
	fg_color := random_color()
	header := "${emoji} Reminders ${emoji}"
	println(term.bold(term.rgb(fg_color.r, fg_color.g, fg_color.b, header)))
	for reminder in all_reminders {
		mut msg := "[${reminder.id}]/(${reminder.uuid[reminder.uuid.len - 5..]}) - ${reminder.name}"
		msg = term.rgb(fg_color.r, fg_color.g, fg_color.b, msg)
		println(msg)
	}
}

fn sync_reminders(cfg Config)! {
	sync_to_remote(cfg)!
}

fn wipe_reminders(cfg Config)! {
	// db := if cfg.db_local { connect_sqlite(resolve_local_db_path())! } else { connect_postgres(cfg)! }
	db := connect_sqlite(resolve_local_db_path())!

	confirm := os.input("Confirm (Y/N): ")
	mut confirmed := false
	match confirm {
		"N"  { return }
		"n"  { return }
		"Y"  { confirmed = true }
		"y"  { confirmed = true }
		else { return }
	}

	if !confirmed { return }

	sql db {
		delete from Reminder where id != 0
	}!
}

fn symlink_cmd(args []string)! {
	link_path := os.expand_tilde_to_home("~/bin/bn")
	me := os.executable()
	println("attempting to symlink '${me}'")
	os.rm(link_path) or {}
	os.symlink(me, link_path) or {
		return error("failed to symlink to ${link_path}: ${err}")
	}
	println("successfully symlinked to ${link_path}")
}

fn init_cmd(args []string)! {
	// cfg := resolve_config()!
	// db := if cfg.db_local { connect_sqlite(resolve_local_db_path())! } else { connect_postgres(cfg)! }
	location := resolve_local_db_path()
	db := connect_sqlite(location)!
	// location := if cfg.db_local { resolve_local_db_path() } else { cfg.db_host }
	println("setting up db @ ${location}")
	sql db {
		create table Reminder
	}!
}

fn rgb2ansi_cmd(args []string)! {
	if args.len < 2 { return error("missing rgb to convert to ansii") }
	rgb_arg_split := args[1].split(",")
	if rgb_arg_split.len < 3 { return error("expected R,G,B values, got ${args[1]} instead") }
	color := ansii.Color.new(rgb_arg_split[0], rgb_arg_split[1], rgb_arg_split[2]) or {
		return error("failed to convert RGB into color: ${err}")
	}
	ansi_color := ansii.rgb2ansi(color)
	print('\x1b[38;5;${ansi_color}m')
	print(ansi_color)
	print('\x1b[49m\n')
}

fn add_cmd(args []string)! {
	cfg := resolve_config()!
	if args.len < 2 { return error("missing name of type 'reminder' to add") }
	match args[1] {
		"reminder" {
			if args.len < 3 { return error("missing reminder description") }
			db := connect_sqlite(resolve_local_db_path())!
			store_reminder(cfg, db, rand.ulid, args[2])!
		}
		else { return error("unknown type '${args[1]}' to add") }
	}
}

fn remove_cmd(args []string)! {
	cfg := resolve_config()!
	if args.len < 2 { return error("missing name of type 'reminder' to remove") }
	match args[1] {
		"reminder-id" {
			if args.len < 3 { return error("missing reminder id") }
			reminder_id := strconv.atoi(args[2]) or { return error("${args[2]} is not a valid integer") }
			db := connect_sqlite(resolve_local_db_path())!
			remove_reminder_id(cfg, db, reminder_id)!
		}
		"reminder" {
			if args.len < 3 { return error("missing reminder id") }
			reminder_ulid := args[2]
			remove_reminder_ulid(cfg, reminder_ulid)!
		}
		else { return error("unknown type '${args[1]}' to remove") }
	}
}

fn list_cmd(args []string)! {
	cfg := resolve_config()!
	if args.len < 2 { return error("missing name of type 'reminders' or 'notifications' to list") }
	match args[1] {
		"reminders" {
			list_reminders(cfg)!
		}
		else { return error("unknown type '${args[1]}' to list") }
	}
}

fn sync_cmd(args []string)! {
	cfg := resolve_config()!
	if args.len < 2 { return error("missing name of type 'reminders' or 'notifications' to list") }
	match args[1] {
		"reminders" {
			sync_reminders(cfg)!
		}
		else { return error("unknown type '${args[1]}' to list") }
	}
}

fn wipe_cmd(args []string)! {
	cfg := resolve_config()!
	if args.len < 2 { return error("missing name of type 'reminders' or 'notifications' to list") }
	match args[1] {
		"reminders" {
			wipe_reminders(cfg)!
		}
		else { return error("unknown type '${args[1]}' to list") }
	}
}

fn exec_args(db_addr string, args []string)! {
	if args.len == 0 { return error("no arguments provided") }

	match args[0] {
		"symlink" {
			symlink_cmd(args)!
		}

		"init" {
			init_cmd(args)!
		}

		"rgb2ansii" {
			rgb2ansi_cmd(args)!
		}

		"add" {
			add_cmd(args)!
		}

		"remove" {
			remove_cmd(args)!
		}

		"list" {
			list_cmd(args)!
		}

		"sync" {
			sync_cmd(args)!
		}

		"wipe" {
			wipe_cmd(args)!
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
	ui.Color{ r: 242, g: 58, b: 218 }
	ui.Color{ r: 41, g: 255, b: 134 }
	ui.Color{ r: 227, g: 145, b: 91 }
]

fn random_color() ui.Color {
	return randomly_choose_color(get_date_as_unix(fn () time.Time { return time.now() }))
}

fn random_emoji() string {
	return randomly_choose_emoji(get_date_as_unix(fn () time.Time { return time.now() }))
}

fn randomly_choose_color(seed int) ui.Color {
	rand.seed([u32(seed), 111333])
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
