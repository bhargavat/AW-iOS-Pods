// The contents of this file will be executed before any of
// your view controllers are ever executed, including the index.
// You have access to all functionality on the `Alloy` namespace.
//
// This is a great place to do any initialization for your app
// or create any global variables/functions that you'd like to
// make available throughout your app. You can easily make things
// accessible globally by attaching them to the `Alloy.Globals`
// object. For example:
//
// Alloy.Globals.someGlobalFunction = function(){};

// Initialize data collections
var bbCollection = Backbone.Collection.extend();
Alloy.Collections.twoitemlist = new bbCollection(); //index.js list
Alloy.Collections.userlist = new bbCollection(); //GeneralInformation.js list
Alloy.Collections.devicelist = new bbCollection(); //GeneralInformation.js list