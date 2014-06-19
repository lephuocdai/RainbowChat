exports.validateUser = function() {

    var ff = require('ffef/FatFractal');  // import the FatFractal library
    var user = ff.getEventHandlerData();
    
    function ActivationRequest(usr) {
       this.clazz = "ActivationRequest";
       this.userGuid = user.guid;
       this.createdBy = 'system';
    }

    var ar = new ActivationRequest(user);

    var activateRequest = ff.createObjAtUri(ar, "/ActivationRequest");
    var apparentAppAddress = ff.getHttpsAppAddress();    
    appAddress = apparentAppAddress;
    // if(appAddress.match(/http.*localhost.*/)) appAddress = ff.getHttpsAppAddress(); 

    var link = appAddress + "/ff/ext/verifyRegistration?guid=" + activateRequest.guid;

    var emailMsg = "Welcome!  To validate your account, please click on this link: " + link;
    ff.sendSMTPEmail("smtp.gmail.com", "465", "true", "465", "info@presentice.com", "ChUs6afa", "info@presentice.com", user.email, "Rainbowchat registration need to be verified", emailMsg);
}