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

Timetrap supports several output formats.  The default is a plain text format.

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

You can also output csv for easy import into a spreadsheet.

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

Or to ical format for import into a calendar program (remember commands can be abbreviated).

    $ t d -f ical > MyTimeSheet.ics

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
  one doesn't exist.  Prints path to config file.  Currently allows configuration
  of path to database file, and the number of seconds used when the `--round`
  flag is set (defaults to 15 minutes.)

  usage: ``t configure``

**display**
  Display a given timesheet. If no timesheet is specified, show the current
  timesheet. If ``all`` is passed as SHEET display all timesheets. Accepts
  an optional ``--ids`` flag which will include the entries' ids in the output.
  This is useful when editing an non running entry with ``edit``.

  Display is designed to support a variety of export formats that can be
  specified by passing the ``--format`` flag.  This currently defaults to
  text.  iCal and csv output are also supported.

  Display also allows the use of a ``--round`` or ``-r`` flag which will round
  all times in the output. See global options below.

  usage: ``t display [--ids] [--round] [--start DATE] [--end DATE] [--format FMT] [SHEET | all]``

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

**sheet**
  Switch to a timesheet creating it if necessary. The default timesheet is
  called "default". When no sheet is specified list all existing sheets.

  usage: ``t sheet [TIMESHEET]``

**week**
  Shortcut for display with start date set to monday of this week

  usage: ``t week [--ids] [--end DATE] [--format FMT] [TIMESHEET | all]``

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

Configuration of TimeTrap's behavior can be done through a YAML config file.
See ``t configure`` for details.  Currently supported options are:

 ``round_in_seconds``: The duration of time to use for rounding with the -r flag

 ``database_file``: The file path of the sqlite database

 ``append_notes_delimiter``: delimiter used when appending notes via ``t edit --append``

Special Thanks
--------------

The initial version of Timetrap was heavily inspired by Trevor Caira's
Timebook, a small python utility.

Original Timebook available at:
http://bitbucket.org/trevor/timebook/src/

Bugs and Feature Requests
--------
Submit to http://github.com/samg/timetrap/issues
