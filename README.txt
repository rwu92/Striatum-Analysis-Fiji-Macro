WHAT THIS TOOL DOES
-------------------
You have microscope images of striatum tissue. This tool helps you:

  1. Draw 3 lines (arrows) and 3 boxes on each image, marking the
     regions you want measured.
  2. Automatically save those measurements as spreadsheet files
     (CSVs) you can analyze later.

It works on hundreds of images in one sitting, remembers where you
left off, and can be safely stopped and restarted any time.


BEFORE YOU START: ONE-TIME FOLDER SETUP
----------------------------------------
Somewhere on your computer, you need ONE folder that will hold all
your results. Inside that folder, create two empty folders named
EXACTLY:

  - ROIs
  - CSVfiles

(Capitalization and spelling matter -- type them exactly as shown.)

You only need to do this once, ever -- not before every session.


EVERY TIME YOU OPEN FIJI TO WORK ON THIS
-----------------------------------------
There are TWO files you'll use. They must be run IN THIS ORDER,
EVERY TIME YOU RESTART FIJI:

STEP 1 -- Turn on the shortcuts (do this first, every time)

  1. Open Fiji.
  2. Find the file called "Install_Shortcuts.ijm" on your computer.
  3. Drag it onto the main Fiji window (the small toolbar window
     with menus like File, Edit, Image...).
  4. A new window will pop up showing the code. Click the Run
     button.
  5. Nothing visible will happen -- that's normal! It worked
     silently in the background.

  This turns on three keyboard shortcuts for the rest of your Fiji
  session:

    r  ->  switches to the rectangle-drawing tool
    a  ->  switches to the arrow-drawing tool
    b  ->  marks the image you just finished to be redone
           (see "Fixing a mistake" below)

  You must repeat this step every time you close and reopen Fiji.
  The shortcuts turn off when Fiji closes.

STEP 2 -- Run the actual quantification tool

  1. Find the file called
     "Striatum_analysis_macro_fiji_BATCH.ijm".
  2. Drag it onto the main Fiji window, same as before.
  3. Click Run.
  4. A window will pop up asking you to choose the folder to SAVE
     RESULTS TO -- pick the folder with your ROIs and CSVfiles
     folders inside it (see setup above).
  5. Another window will pop up asking you to choose the folder
     WITH YOUR IMAGES -- pick the folder containing all your
     microscope images (subfolders inside it are fine, it finds
     everything automatically).
  6. It will briefly scan your files, then start showing you images
     one at a time.


TRACING EACH IMAGE
-------------------
For every image, a small message box will appear telling you what
to do. In short:

  1. Press r or a to pick your tool (rectangle or arrow).
  2. Draw your 3 arrows first, then your 3 boxes -- click the tool
     button "Add to Manager" or press t after each shape to add it
     to the ROI list. (This part is unchanged from your normal
     workflow.)
  3. Once you have all 6 shapes drawn, either click OK on the
     message box, or just press Enter on your keyboard -- both do
     the same thing.
  4. The tool automatically saves everything and moves on to the
     next image.

If you have the wrong number of shapes (not exactly 6), it will
tell you how many it counted and ask you to fix it before
continuing.

To skip an image entirely (e.g. the tissue is too damaged to
trace): just click OK / press Enter without drawing anything. It
will remember this and never ask about that image again, even in
future sessions.


FIXING A MISTAKE RIGHT AFTER YOU MAKE IT
-------------------------------------------
If you just finished an image and realize you traced something
wrong:

  1. Press b.
  2. Keep going to the next image as normal.
  3. Before opening the image AFTER that, the tool will
     automatically go back and let you redo the one you flagged --
     overwriting your old (wrong) tracing.


STOPPING AND RESUMING
----------------------
You can close Fiji at any time, for any reason -- nothing gets
lost. When you come back:

  1. Repeat Step 1 (run Install_Shortcuts.ijm again).
  2. Repeat Step 2 (run the batch macro again, choosing the SAME
     two folders as before).

The tool automatically remembers which images are already done and
skips straight past them -- you'll only be asked about images you
haven't traced yet.


WHERE TO FIND YOUR RESULTS
----------------------------
Inside the output folder you chose:

  ROIs               - your saved shape tracings for every image
                        (in case you need to check or redo one
                        later)
  CSVfiles            - the actual measurement spreadsheets, ready
                        for analysis
  processing_log.csv  - a record of every image you've completed,
                        when, and which color channel was used
  skipped_images.txt   - a list of any images you chose to skip


COMMON PROBLEMS
-----------------

"I get a red error message mentioning FileNotFoundException or
cannot find the path specified"

  This almost always means the folder you picked when asked
  "choose the folder to save output to" was the wrong one --
  usually one level too high or too low. Double check you selected
  the folder that directly contains your ROIs and CSVfiles
  folders, not its parent or a folder inside it.

"My keyboard shortcuts (r, a, b) aren't doing anything"

  You likely forgot Step 1 this session. Run Install_Shortcuts.ijm
  again -- remember, this has to be redone every time you reopen
  Fiji.

"The processing_log.csv file is empty"

  This happens if every image attempted so far hit an error
  partway through (like the FileNotFoundException above) before it
  could finish and get logged. Fix the underlying error first, and
  successfully completed images will start appearing in the log.

"A pop-up appeared asking me which channel to use"

  This only happens on images with more than one color channel.
  Pick the correct one once -- it will remember your answer and
  use it automatically for the rest of your images this session.


QUICK REFERENCE CARD
-----------------------
  r       Switch to rectangle tool
  a       Switch to arrow tool
  b       Redo the image you just finished
  Enter   Same as clicking OK
