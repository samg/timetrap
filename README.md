Timetrap
========

Timetrap is a simple command line time tracker written in ruby. It provides an
easy to use command line interface for tracking what you spend your time on.

Getting Started
---------------

To install:

    $ gem install timetrap

This will place a ``t`` executable in your path.

### Basic Usage

    $ # get help
    $ t --help

Timetrap maintains a list of *timesheets*.

    $ # create the "coding" timesheet
    $ t sheet coding
    Switching to sheet coding

All commands can be abbreviated.

    $ # same as "t sheet coding"
    $ t s coding
    Switching to sheet coding

Each timesheet contains *entries*.  Each entry has a start and end time, and a
note associated with it.  An entry without an end time set is considered to be
running.

You check in to the current sheet with the `in` command.

    $ # check in with "document timetrap" note
    $ t in document timetrap
    Checked into sheet "coding".

Commands like `display` and `now` will show you the running entry.

    $ t display
    Timesheet: coding
        Day                Start      End        Duration   Notes
        Sun Nov 28, 2010   12:26:10 -            0:00:03    document timetrap
                                                 0:00:03
        ---------------------------------------------------------
        Total                                    0:00:03

    $ t now
    *coding: 0:01:02 (document timetrap)

If you make a mistake use the `edit` command.

    $ # edit the running entry's note
    $ t edit writing readme
    editing entry #42

You check out with the `out` command.

    $ t out
    Checked out of sheet "coding"

You can edit entries that aren't running using `edit`'s `--id` or `-i` flag.
`t display --ids`  (or `t display -v`) will tell you the ids.

    $ # note id column in output
    $ t d -v
    Timesheet: coding
    Id  Day                Start      End        Duration   Notes
    43  Sun Nov 28, 2010   12:26:10 - 13:41:03   1:14:53    writing readme
                                                 1:14:53
        ---------------------------------------------------------
        Total                                    1:14:53

    $ # -i43 to edit entry 43
    $ t e -i43 --end "2010-11-28 13:45"
    editing entry #43

    $ t d
    Timesheet: coding
        Day                Start      End        Duration   Notes
        Sun Nov 28, 2010   12:26:10 - 13:45:00   1:18:50    writing readme
                                                 1:18:50
        ---------------------------------------------------------
        Total                                    1:18:50


### Natural Language Times

Commands such as `in`, `out`, `edit`, and `display` have flags that accept
times as arguments.  Any time you pass Timetrap a time it will try to parse it
as a natural language time.

This is very handy if you start working and forget to start Timetrap.  You can
check in 5 minutes ago using `in`'s `--at` flag.

    $ t in --at "5 minutes ago"

Command line flags also have short versions.

    $ # equivilent to the command above
    $ t i -a "5 minutes ago"

You can consult the Chronic gem (http://chronic.rubyforge.org/) for a full
list of parsable time formats, but all of these should work.

    $ t out --at "in 30 minutes"
    $ t edit --start "last monday at 10:30am"
    $ t edit --end "tomorrow at noon"
    $ t display --start "10am" --end "2pm"
    $ t i -a "2010-11-29 12:30:00"

### Output Formats

#### Built-in Formatters

Timetrap has built-in support for 6 output formats.

These are **text**, **csv**, **ical**, **json**, and **ids**

The default is a plain **text** format.  (You can change the default format using
`t configure`).

    $ t display
    Timesheet: coding
        Day                Start      End        Duration   Notes
        Mon Apr 13, 2009   15:46:51 - 17:03:50   1:16:59    improved display functionality
                           17:25:59 - 17:26:02   0:00:03
                           18:38:07 - 18:38:52   0:00:45    working on list
                           22:37:38 - 23:38:43   1:01:05    work on kill
                                                 2:18:52
        Tue Apr 14, 2009   00:41:16 - 01:40:19   0:59:03    gem packaging
                           10:20:00 - 10:48:10   0:28:10    working on readme
                                                 1:27:13
        ---------------------------------------------------------
        Total                                    3:46:05

The **CSV** formatters is easy to import into a spreadsheet.

    $ t display --format csv
    start,end,note,sheet
    "2010-08-21 11:19:05","2010-08-21 12:12:04","migrated site","coding"
    "2010-08-21 12:44:09","2010-08-21 12:48:46","DNS emails and install email packages","coding"
    "2010-08-21 12:49:57","2010-08-21 13:10:12","A records","coding"
    "2010-08-21 15:09:37","2010-08-21 16:32:26","setup for wiki","coding"
    "2010-08-25 20:42:55","2010-08-25 21:41:49","rewrote index","coding"
    "2010-08-29 15:44:39","2010-08-29 16:21:53","recaptcha","coding"
    "2010-08-29 21:15:58","2010-08-29 21:30:31","backups","coding"
    "2010-08-29 21:40:56","2010-08-29 22:32:26","backups","coding"

**iCal** format lets you get your time into your favorite calendar program
(remember commands can be abbreviated).

    $ t d -f ical > MyTimeSheet.ics

The **ids** formatter is provided to facilitate scripting within timetrap.  It only
outputs numeric id for the entries.  This is handy if you want to move all entries
from one sheet to another sheet.  You could do something like this:

    $ for id in `t display sheet1 -f ids`; do t edit --id $id --move sheet2; done
    editing entry #36
    editing entry #37
    editing entry #44
    editing entry #46

A *json* formatter is provided because hackers love json.

    $ t d -fjson

#### Custom Formatters

Timetrap tries to make it easy to define custom output formats.

You're encouraged to submit these back to timetrap for inclusion in a future
version.

To create a custom formatter you create a ruby class and implement two methods
on it.

As an example we'll create a formatter that only outputs the notes from
entries.

To ensure that timetrap can find your formatter put it in
`~/.timetrap/formatters/notes.rb`.  The filename should be the same as the
string you will pass to `t d --format` to invoke it.  If you want to put your
formatter in a different place you can run `t configure` and edit the
`formatter_search_paths` option.

All timetrap formatters live under the namespace `Timetrap::Formatters` so
define your class like this:

    class Timetrap::Formatters::Notes
    end

When `t display` is invoked, timetrap initializes a new instance of the
formatter passing it an Array of entries.  It then calls `#output` which should
return a string to be printed to the screen.

This means we need to implement an `#initialize` method and an `#output`
method for the class.  Something like this:

    class Timetrap::Formatters::Notes
      def initialize(entries)
        @entries = entries
      end

      def output
        @entries.map{|entry| entry[:note]}.join("\n")
      end
    end

Now when I invoke it:

    $ t d -f notes
    working on issue #123
    working on issue #234

Timetrap Formatters Repository
------------------------------

A community focused repository of custom formatters is available at
https://github.com/samg/timetrap_formatters.

Commands
--------
**archive**
  Archives the selected entries (by moving them to a sheet called ``_[SHEET]``)
  These entries can be seen by running ``t display _[SHEET]``.
  usage: ``t archive [--start DATE] [--end DATE] [SHEET]``

**backend**
  Run an interactive database session on the timetrap database. Requires the
  sqlite3 command.

  usage: ``t backend``

**configure**
  Creates a config file at  ``~/.timetrap.yml`` or ``ENV['TIMETRAP_CONFIG_FILE']`` if
  one doesn't exist.  If one does exist it will update it with new
  configuration options preserving any user overrides. Prints path to config
  file.  This file may contain ERB.

  usage: ``t configure``

**display**
  Display a given timesheet. If no timesheet is specified, show the current
  timesheet. If ``all`` is passed as SHEET display all timesheets. If ``full``
  is passed as SHEET archived timesheets are displayed as well. Accepts an
  optional ``--ids`` flag which will include the entries' ids in the output.
  This is useful when editing an non running entry with ``edit``.

  Display is designed to support a variety of export formats that can be
  specified by passing the ``--format`` flag.  This currently defaults to
  text.  iCal, csv, json, and numeric id output are also supported.

  Display also allows the use of a ``--round`` or ``-r`` flag which will round
  all times in the output. See global options below.

  usage: ``t display [--ids] [--round] [--start DATE] [--end DATE] [--format FMT] [SHEET | all | full]``

**edit**
  Inserts a note associated with the an entry in the timesheet, or edits the
  start or end times.  Defaults to the current time although an ``--id`` flag can
  be passed with the entry's id (see display.)

  usage: ``t edit [--id ID] [--start TIME] [--end TIME] [--append] [NOTES]``

**in**
  Start the timer for the current timesheet. Must be called before out.  Notes
  may be specified for this period. This is exactly equivalent to
  ``t in; t edit NOTES``. Accepts an optional --at flag.

  usage: ``t in [--at TIME] [NOTES]``

**kill**
  Delete a timesheet or an entry.  Entry's are referenced using an ``--id``
  flag (see display).  Sheets are referenced by name.

  usage: ``t kill [--id ID] [TIMESHEET]``

**list**
  List the available timesheets.

  usage: ``t list``

**now**
  Print a description of all running entries.

  usage: ``t now``

**out**
  Stop the timer for the current timesheet. Must be called after in. Accepts an
  optional --at flag. Accepts an optional TIMESHEET name to check out of a
  running, non-current sheet.

  usage: ``t out [--at TIME] [TIMESHEET]``

**resume**
  Start the timer for the current timesheet with the same notes as the last entry.
  If there is no last entry the new one has blank notes ore uses the optional
  NOTES parameter.

  usage: ``t resume [--at TIME] [NOTES]``

**sheet**
  Switch to a timesheet creating it if necessary. The default timesheet is
  called "default". When no sheet is specified list all existing sheets.
  The special timesheet name '-' will switch to the last active sheet.

  usage: ``t sheet [TIMESHEET]``

**week**
  Shortcut for display with start date set to monday of this week

  usage: ``t week [--ids] [--end DATE] [--format FMT] [TIMESHEET | all]``

**month**
  Shortcut for display with start date set to the beginning of this month
  (or a specified month) and end date set to the end of the month.

  usage: ``t month [--ids] [--start MONTH] [--format FMT] [TIMESHEET | all]``


Global Options
--------

**rounding**
  passing a ``--round`` or ``-r`` flag to any command will round entry start
  and end times to the closest 15 minute increment.  This flag only affects the
  display commands (e.g. display, list, week, etc.) and is non-destructive.
  The actual start and end time stored by Timetrap are unaffected.

  See `configure` command to change rounding increment from 15 minutes.

**non-interactive**
  passing a ``--yes`` or ``-y`` flag will cause any command that requires
  confirmation (such as ``kill``) to assume an affirmative response to any
  prompt. This is useful when timetrap is used in a scripted environment.

Configuration
--------

Configuration of TimeTrap's behavior can be done through an ERB interpolated
YAML config file.

See ``t configure`` for details.  Currently supported options are:

  **round_in_seconds**: The duration of time to use for rounding with the -r flag

  **database_file**: The file path of the sqlite database

  **append_notes_delimiter**: delimiter used when appending notes via `t edit --append`

  **formatter_search_paths**: an array of directories to search for user defined fomatter classes

  **default_formatter**: The format to use when display is invoked without a `--format` option

  **default_command**: The default command to invoke when you call `t`

Special Thanks
--------------

The initial version of Timetrap was heavily inspired by Trevor Caira's
Timebook, a small python utility.

Original Timebook available at:
http://bitbucket.org/trevor/timebook/src/

Bugs and Feature Requests
--------
Submit to http://github.com/samg/timetrap/issues
