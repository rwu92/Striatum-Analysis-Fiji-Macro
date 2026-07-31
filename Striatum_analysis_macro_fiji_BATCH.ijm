//***BATCH VERSION — single-channel***
//Pick the FOLDER of images once, then the folder to save output to.
//The macro loops through every image, pausing only for you to trace the
//DV/ML/MV-DL arrows + 3 noise boxes.
//Already-processed images (ROI file already exists) are automatically skipped,
//so you can safely stop partway through and resume later.
//
//NEW: every processed image is logged to processing_log.csv (filename,
//timestamp, channel used, session).
//NEW: press "b" (after installing Install_Shortcuts.ijm once) right after
//finishing an image to queue a redo of that image -- it reprocesses on the
//next loop pass, before moving to the next new image.
//NEW: press "r"/"a" (after installing Install_Shortcuts.ijm once) any time
//to switch to the Rectangle/Arrow tool -- no toolbar clicking needed.
//The "trace ROIs" prompt itself can be dismissed either by clicking OK, or
//by pressing Enter/Return (works natively, no shortcut needed) -- same
//"0 ROIs = skip this image" rule applies either way.
//
//IMPORTANT: run Install_Shortcuts.ijm ONCE per Fiji session BEFORE running
//this file, to activate the r/a/b shortcuts. (These two must stay separate
//files -- ImageJ treats a file containing macro{} shortcut blocks as an
//installer only and won't run any other code in it.)

//Choose the output folder -- must already contain subfolders: ROIs, CSVfiles
output = getDirectory("Choose the folder to save output to (must already contain ROIs and CSVfiles subfolders)");

//Recursively collect every file path under a folder, including subfolders
function listFilesRecursive(dir) {
	names = getFileList(dir);
	all_paths = newArray(0);
	for (i = 0; i < names.length; i++) {
		if (endsWith(names[i], "/")) {
			//It's a subfolder -- recurse into it
			sub_paths = listFilesRecursive(dir + names[i]);
			all_paths = Array.concat(all_paths, sub_paths);
		} else {
			all_paths = Array.concat(all_paths, dir + names[i]);
		}
	}
	return all_paths;
}

//Choose the TOP folder containing all your images (subfolders included)
input_dir = getDirectory("Choose the folder containing your images");
showStatus("Finding all images (including subfolders)...");
all_paths = listFilesRecursive(input_dir);

processed_count = 0;
skipped_count = 0;
user_skipped_count = 0;
remembered_channel = -1;  //-1 means "not yet asked"; set on first multi-channel image, reused after that

//Persistent list of user-skipped images -- a plain text file, one filename per
//line. Loaded once here; checked before even opening an image, so a skipped
//image is never reopened on future runs either.
skip_list_path = output + "skipped_images.txt";
skipped_files = newArray(0);
if (File.exists(skip_list_path)) {
	skip_content = File.openAsString(skip_list_path);
	skipped_files = split(skip_content, "\n");
}

function isInArray(arr, value) {
	for (i = 0; i < arr.length; i++) {
		if (arr[i] == value) return true;
	}
	return false;
}

//Pre-scan: count how many images actually need processing this session
//(same filters as the main loop, but no opening -- just filename checks),
//so the pace/ETA estimate below has a real denominator to work with.
//Shows a progress bar in the main Fiji toolbar while it scans.
total_to_process = 0;
showStatus("Scanning images...");
for (scan_i = 0; scan_i < all_paths.length; scan_i++) {
	showProgress(scan_i, all_paths.length);
	scan_name = File.getName(all_paths[scan_i]);
	scan_name_lower = toLowerCase(scan_name);
	scan_is_tiff = endsWith(scan_name_lower, ".tif") || endsWith(scan_name_lower, ".tiff");
	scan_is_maxip = indexOf(scan_name_lower, "maxip") >= 0;
	if (scan_is_tiff || !scan_is_maxip) continue;
	if (isInArray(skipped_files, scan_name)) continue;
	scan_roi_check = output + "ROIs" + File.separator + scan_name + "ROIset.zip";
	if (File.exists(scan_roi_check)) continue;
	total_to_process = total_to_process + 1;
}
showProgress(1.0);
showStatus("Ready -- " + total_to_process + " image(s) to process this session.");

//Pace tracking -- average time per FULLY PROCESSED image (skips excluded,
//since they take moments and would understate real tracing time)
total_time_minutes = 0;
timed_image_count = 0;

//Processing log -- filename, timestamp, channel used, session
log_path = output + "processing_log.csv";
if (!File.exists(log_path)) {
	File.saveString("Filename,Timestamp,Channel,Session\n", log_path);
}

function getTimestamp() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	return "" + year + "-" + IJ.pad(month+1,2) + "-" + IJ.pad(dayOfMonth,2) + " " + IJ.pad(hour,2) + ":" + IJ.pad(minute,2) + ":" + IJ.pad(second,2);
}

session_id = getTimestamp(); //fixed once at the start of this run, identifies this session in the log

//"Go back" mechanism: a small flag file at a fixed, known location (ImageJ's
//temp folder, so it doesn't depend on which output folder you picked this
//run). The installed "b" shortcut (see Install_Shortcuts.ijm) just touches
//this file; the main loop checks for it before opening each new image.
redo_flag_path = getDirectory("temp") + "redo_request.flag";
lastProcessed_fullPath = "";
lastProcessed_fileName = "";

//Processes one image end-to-end: open, channel select, trace, extract, save,
//log. Returns true if it was actually processed, false if user chose to skip.
function processOneImage(full_path, file_name, position_label) {

	run("Bio-Formats Importer", "open=[" + full_path + "] color_mode=Default view=Hyperstack stack_order=XYCZT");

	image_name = file_name;
	rename(image_name);

	getDimensions(dummy_w, dummy_h, nChannels, dummy_slices, dummy_frames);
	channel_used = "1 (single-channel)";

	if (nChannels > 1) {
		if (remembered_channel == -1) {
			channelList = newArray(nChannels);
			for (c = 1; c <= nChannels; c++) {
				channelList[c-1] = "" + c;
			}
			Dialog.create("Select channel to quantify");
			Dialog.addMessage(file_name + "\nhas " + nChannels + " channels. Check the Channels Tool (Image > Color > Channels Tool) if you're unsure which number corresponds to which color.\n\nThis will be remembered and reused automatically for every other multi-channel image in this batch.");
			Dialog.addChoice("Channel to quantify:", channelList, channelList[0]);
			Dialog.show();
			remembered_channel = parseInt(Dialog.getChoice());
		}
		channel_used = "" + remembered_channel;

		run("Duplicate...", "duplicate channels=" + remembered_channel);
		single_channel_title = getTitle();
		close(image_name);
		selectImage(single_channel_title);
		rename(image_name);
	}

	selectImage(image_name);
	run("Enhance Contrast", "saturation=0.35");

	//Arrow tool preloaded automatically on image open -- switch to rectangle
	//yourself when you're ready for the 3 noise boxes.
	setTool("arrow");

	roi_count = 0;
	first_prompt = true;
	skip_this_image = false;
	while (roi_count != 6 && !skip_this_image) {
		if (first_prompt) {
			waitForUser(position_label + ": \nTrace the DV, ML, MV-DL arrows and 3 noise boxes in that order, then click OK (or press Enter).\n\nTo SKIP this image entirely, just click OK/Enter without adding any ROIs.");
			first_prompt = false;
			roi_count = roiManager("count");
			if (roi_count == 0) {
				skip_this_image = true;
			}
		} else {
			waitForUser("You have " + roi_count + " ROI(s) instead of the required 6 (3 arrows + 3 noise boxes). \nPlease add the missing ROI(s), then click OK (or press Enter) to continue.");
			roi_count = roiManager("count");
		}
	}

	if (skip_this_image) {
		File.append(file_name, skip_list_path);
		user_skipped_count = user_skipped_count + 1;

		selectImage(image_name);
		close();
		roiManager("reset");
		return false;
	}

	selectImage(image_name);
	roiManager("Show All");

	//Save the ROIs
	roiManager("save", output + "ROIs" + File.separator + image_name + "ROIset.zip");

	//-----------------------------------------------------------------
	//Extract the data

	//DV
	selectImage(image_name);
	roiManager("Select", 0);
	run("Clear Results");
	profile = getProfile();
	for (i=0; i<profile.length; i++) setResult("Value", i, profile[i]);
	updateResults;
	saveAs("Results", output + "CSVfiles" + File.separator + "DV_" + image_name + ".csv");

	//ML
	selectImage(image_name);
	roiManager("Select", 1);
	run("Clear Results");
	profile = getProfile();
	for (i=0; i<profile.length; i++) setResult("Value", i, profile[i]);
	updateResults;
	saveAs("Results", output + "CSVfiles" + File.separator + "ML_" + image_name + ".csv");

	//MV-DL
	selectImage(image_name);
	roiManager("Select", 2);
	run("Clear Results");
	profile = getProfile();
	for (i=0; i<profile.length; i++) setResult("Value", i, profile[i]);
	updateResults;
	saveAs("Results", output + "CSVfiles" + File.separator + "MV-DL_" + image_name + ".csv");

	//-----------------------------------------------------------------
	//Remove the 3 arrow ROIs, leaving only the noise boxes, then measure + save
	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Select", 0);
	roiManager("Delete");

	selectImage(image_name);
	roiManager("Show All");
	roiManager("Measure");
	saveAs("Measurements", output + "CSVfiles" + File.separator + "Noise_" + image_name + ".csv");
	run("Clear Results");

	//-----------------------------------------------------------------
	//Close this image and reset the ROI manager for the next one
	selectImage(image_name);
	close();
	roiManager("reset");

	File.append(file_name + "," + getTimestamp() + "," + channel_used + "," + session_id, log_path);

	return true;
}

for (f = 0; f < all_paths.length; f++) {

	full_path = all_paths[f];
	file_name = File.getName(full_path);
	file_name_lower = toLowerCase(file_name);

	//Only keep files that are NOT tiffs AND whose name contains "maxip"
	//(skips raw z-stack .nd2 files and any .tif/.tiff files automatically)
	is_tiff = endsWith(file_name_lower, ".tif") || endsWith(file_name_lower, ".tiff");
	is_maxip = indexOf(file_name_lower, "maxip") >= 0;
	if (is_tiff || !is_maxip) {
		continue;
	}

	//Skip images the user has previously marked to skip -- checked BEFORE
	//opening, so these are never reopened on future runs
	if (isInArray(skipped_files, file_name)) {
		continue;
	}

	//Skip images already processed in a previous session
	roi_check = output + "ROIs" + File.separator + file_name + "ROIset.zip";
	if (File.exists(roi_check)) {
		skipped_count = skipped_count + 1;
		continue;
	}

	//Check for a queued "redo previous image" request (via the "b" shortcut)
	//before starting this new image -- reprocesses the previous one first,
	//overwriting its old ROI/CSV files, then continues on to this image.
	if (File.exists(redo_flag_path)) {
		File.delete(redo_flag_path);
		if (lastProcessed_fileName != "") {
			showStatus("Redoing previous image: " + lastProcessed_fileName);
			was_processed = processOneImage(lastProcessed_fullPath, lastProcessed_fileName, "REDO: " + lastProcessed_fileName);
			if (was_processed) {
				processed_count = processed_count + 1;
			}
		}
	}

	//Build the pace/ETA message (only shows once at least 1 image has been
	//timed this session -- no data to estimate from before that)
	pace_info = "";
	if (timed_image_count > 0) {
		avg_time = total_time_minutes / timed_image_count;
		attempted_so_far = processed_count + user_skipped_count;
		remaining = total_to_process - attempted_so_far;
		if (remaining < 0) remaining = 0;
		eta_minutes = avg_time * remaining;
		pace_info = "\n\nPace: ~" + d2s(avg_time,1) + " min/image -- ~" + d2s(eta_minutes,0) + " min remaining for " + remaining + " image(s) left.";
	}

	current_position = processed_count + user_skipped_count + 1;
	image_start_time = getTime();
	was_processed = processOneImage(full_path, file_name, "Image " + current_position + " of " + total_to_process + " (" + (processed_count+1) + " done this session)" + pace_info);
	elapsed_minutes = (getTime() - image_start_time) / 1000.0 / 60.0;

	if (was_processed) {
		processed_count = processed_count + 1;
		lastProcessed_fullPath = full_path;
		lastProcessed_fileName = file_name;
		total_time_minutes = total_time_minutes + elapsed_minutes;
		timed_image_count = timed_image_count + 1;
	}
}

pace_summary = "";
if (timed_image_count > 0) {
	pace_summary = "\nAverage pace: ~" + d2s(total_time_minutes / timed_image_count, 1) + " min/image this session.";
}

showMessage("Batch complete", "Processed " + processed_count + " new image(s) this session.\nSkipped " + skipped_count + " already-completed image(s).\nSkipped " + user_skipped_count + " image(s) by choice this session." + pace_summary + "\n\nLog saved to: " + log_path);
