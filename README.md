Timetrap
========

Timetrap is a ruby port of Trevor Caira's Timebook, a small utility which aims
to be a low-overhead way of tracking what you spend time on.  Timetrap
maintains its state in a sqlite3 database.

To install:

    $ gem sources -a http://gems.github.com (you only have to do this once)
    $ sudo gem install samg-timetrap

This will place a ``t`` executable in your path.

Original Timebook available at:
http://bitbucket.org/trevor/timebook/src/


Concepts
--------

Timetrap maintains a list of *timesheets* -- distinct lists of timed *periods*.
Each period has a start and end time, with the exception of the most recent
period, which may have no end time set. This indicates that this period is
still running. Timesheets containing such periods are considered *active*. It
is possible to have multiple timesheets active simultaneously, though a single
time sheet may only have one period running at once.

Interactions with timetrap are performed through the ``t`` command on the
command line. ``t`` is followed by one of timetrap's subcommands.  Often used
subcommands include ``in``, ``out``, ``switch``, ``now``, ``list`` and
``display``. Commands may be abbreviated as long as they are unambiguous: thus
``t switch foo`` and ``t s foo`` are identical.  With the default command set,
no two commands share the first same letter, thus it is only necessary to type
the first letter of a command.  Likewise, commands which display timesheets
accept abbreviated timesheet names. ``t display f`` is thus equivalent to ``t
display foo`` if ``foo`` is the only timesheet which begins with "f". Note that
this does not apply to ``t switch``, since this command also creates
timesheets.  (Using the earlier example, if ``t switch f`` is entered, it would
thus be ambiguous whether a new timesheet ``f`` or switching to the existing
timesheet ``foo`` was desired).

Usage
-----

The basic usage is as follows::

    $ t switch writing
    $ t in document timetrap --at "10 minutes ago"
    $ t out

The first command, ``t switch writing``, switches to the timesheet "writing"
(or creates it if it does not exist). ``t in document timetrap --at "10 minutes
ago"`` creates a new period in the current timesheet, and annotates it with the
description "document timetrap". The optional ``--at`` flag can be passed to start
the entry at a time other than the present.  The ``--at`` flag is able to parse
natural language times (via Chronic: http://chronic.rubyforge.org/) and will
understand 'friday 13:00', 'mon 2:35', '4pm', etc. (also true of the ``alter``
command's ``--start`` and ``--end`` flags.)  Note that this command would be in
error if the ``writing`` timesheet was already active.  Finally, ``t out``
records the current time as the end time for the most recent period in the
``writing`` timesheet.

To display the current timesheet, invoke the ``t display`` command::

    $ t display
    Timesheet: timetrap
        Day                Start      End        Duration   Notes
        Mon Apr 13, 2009   15:46:51 - 17:03:50   1:16:59    improved display functionality
                           17:25:59 - 17:26:02   0:00:03
                           18:38:07 - 18:38:52   0:00:45    working on list
                           22:37:38 - 23:38:43   1:01:05    work on kill
                                                 2:18:52
        Tue Apr 14, 2009   00:41:16 - 01:40:19   0:59:03    gem packaging
                           10:20:00 - 10:48:10   0:28:10    enhance alter
                                                 1:27:13
        ---------------------------------------------------------
        Total                                    3:46:05

Each period in the timesheet is listed on a row. If the timesheet is active,
the final period in the timesheet will have no end time. After each day, the
total time tracked in the timesheet for that day is listed. Note that this is
computed by summing the durations of the periods beginning in the day. In the
last row, the total time tracked in the timesheet is shown.

Commands
--------

**alter**
  Inserts a note associated with the an entry in the timesheet, or alters the
  start or end times.  Defaults to the current time although an ``--id`` flag can
  be passed with the entry's id (see display.)

  usage: ``t alter [--id ID] [--start TIME] [--end TIME] [NOTES]``

**backend**
  Run an interactive database session on the timetrap database. Requires the
  sqlite3 command.

  usage: ``t backend``

**display**
  Display a given timesheet. If no timesheet is specified, show the current
  timesheet. If ``all`` is passed as timesheet display all timesheets. Accepts
  an optional ``--ids`` flag which will include the entries' ids in the output.
  This is useful when editing an non running entry with ``alter``.

  usage: ``t display [--ids] [--start DATE] [--end DATE] [TIMESHEET]``

**format**
  Export the current sheet as a comma-separated value format spreadsheet.  If
  the final entry is active, it is ignored.

  Currently must pass 'ical' as FORMATTER

  usage: ``t format [--start DATE] [--end DATE] FORMATTER``

**in**
  Start the timer for the current timesheet. Must be called before out.  Notes
  may be specified for this period. This is exactly equivalent to
  ``t in; t alter NOTES``. Accepts an optional --at flag.

  usage: ``t in [--at TIME] [NOTES]``

**kill**
  Delete a timesheet or an entry.  Entry's are referenced using an ``--id``
  flag (see display).  Sheets are referenced by name.

  usage: ``t kill [--id ID] [TIMESHEET]``

**list**
  List the available timesheets.

  usage: ``t list``

**now**
  Print the current sheet, whether it's active, and if so, how long it has been
  active and what notes are associated with the current period.

  usage: ``t now``

**out**
  Stop the timer for the current timesheet. Must be called after in. Accepts an
  optional --at flag.

  usage: ``t out [--at TIME]``

**running**
  Print all active sheets and any messages associated with them.

  usage: ``t running``

**switch**
  Switch to a new timesheet. this causes all future operation (except switch)
  to operate on that timesheet. The default timesheet is called "default".

  usage: ``t switch TIMESHEET``

