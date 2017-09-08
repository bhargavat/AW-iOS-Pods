(function constructor(args) {
	$.homewin.open();
})(arguments[0] || {});

var controllerNames = ["GeneralInformation", "IntegratedAuth"]; //controller names listed based on the order in which they appear in home page list
var labels_values = getJSONData('staticData/homeItems.json'); //JSON object containing the data from external JSON file
Alloy.Collections.twoitemlist.reset(labels_values);

function onListViewItemclick(e){
	var index = e.itemIndex;
	var controllerName = controllerNames[index].toString();
	$.homewin.openWindow(Alloy.createController(controllerName, {nav: $.homewin}).getView());
}

/**
* Fetch and return JSON data from app/lib/[directory/to/file] file
*/
function getJSONData(directory) {
	var file = Ti.Filesystem.getFile(Ti.Filesystem.resourcesDirectory + directory);
	var key_values = JSON.parse(file.read().text).data;
	
	return key_values;
}