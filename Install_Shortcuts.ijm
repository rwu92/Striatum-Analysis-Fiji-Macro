//Run this ONCE per Fiji session (Plugins > Macros > Install..., or just click
//Run with this file open in the Script Editor) BEFORE running the batch macro.
//It stays active for the rest of your Fiji session -- no need to reinstall
//between images, and no need to reinstall if you just stop/rerun the batch
//macro without closing Fiji. You only need to run this again if you close
//and reopen Fiji itself.
//
//  Press "r" any time -> switches to the Rectangle tool
//  Press "a" any time -> switches to the Arrow tool
//  Press "b" any time -> queues a redo of the image you JUST finished
//                        (retraces it, overwriting its old ROI/CSV files,
//                        on the next loop pass of the batch macro)
//
//For the "trace ROIs" prompt itself: click OK, or just press Enter/Return --
//that already works natively (standard default-button behavior), no custom
//shortcut needed or possible here, since ImageJ doesn't expose a way to
//close that popup from a separate keyboard shortcut.

macro "Rectangle Tool [r]" {
	setTool("rectangle");
}

macro "Arrow Tool [a]" {
	setTool("arrow");
}

macro "Redo Previous Image [b]" {
	File.saveString("redo", getDirectory("temp") + "redo_request.flag");
	showStatus("Redo queued -- will reprocess the previous image next.");
}
