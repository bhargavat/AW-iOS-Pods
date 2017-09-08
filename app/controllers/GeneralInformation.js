var userLabels = getJSONData('staticData/genInfoItems.json', "userInfo"); //JSON object containing the data from external JSON file
var deviceLabels = getJSONData('staticData/genInfoItems.json', "deviceInfo");

Alloy.Collections.userlist.reset(userLabels);
Alloy.Collections.devicelist.reset(deviceLabels);

//var genInfo = require('generalInfo_module');

//var UIView = require('UIKit/UIView');
//Ti.API.info("UIView: " + UIView);
// var AWSDK = require('AWSDK');
//Ti.API.info("AWSDK: " + AWSDK + "| Not null: "+ (AWSDK != null));
//var AWController = require('AirWatchSDK/AWController');
// var controller = new AWController();
//Ti.API.info("controller: " + AWController + "| Not null: "+ (AWController != null));
//Ti.API.info("AWController: " + AWController + "| Not null: "+ (AWController != null));
// var myAWController = AWController.alloc().init();
// Ti.API.info("controller: " + myAWController);
/**
* Fetch and return JSON data from app/lib/[directory/to/file] file 
* @param directory The directory from which to fetch JSON file from
* @param section The section of the JSON file from which to parse data from
* @return {object} a JSON parsed object containing the labels and values needed to dynamically bind data from
*/
function getJSONData(directory, section) {
	var file = Ti.Filesystem.getFile(Ti.Filesystem.resourcesDirectory + directory);
	// Ti.API.info('file: '+ file);
	var key_values;
	switch(section){
		case "userInfo":
			key_values = JSON.parse(file.read().text).userInfo;
			break;
		case "deviceInfo":
			key_values = JSON.parse(file.read().text).deviceInfo;
			break;
	}
	return key_values;
}