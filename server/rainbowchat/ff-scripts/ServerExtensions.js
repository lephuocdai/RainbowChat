exports.verifyRegistration = function() {
    var ff = require('ffef/FatFractal');  // import the FatFractal library
    var data = ff.getExtensionRequestData();
 
    var guid = data.httpParameters['guid'];
    if (! guid) {
        r.result = null;
        r.responseCode = "400";
        r.statusMessage = "ActivationRequest guid not supplied";
        r.mimeType = "application/json";
        return;
    }
 
    var r = ff.response();
 
    var activationRequest = ff.getObjFromUri("/ff/resources/ActivationRequest/" + guid);
 
    var user = ff.getUser(activationRequest.userGuid);
    if (! user) {
        r.result = null;
        r.responseCode = "404";
        r.statusMessage = "User could not be found";
        r.mimeType = "application/json";
        return;
    }
    user.active = true;
    ff.updateObj(user);
    ff.deleteObj(activationRequest);
    r.responseCode = "200";
    var hc = require('ringo/httpclient');
    var htmlContent = hc.get(ff.getHttpsAppAddress() + '/validateuser.html').content;
    htmlContent = htmlContent.replace("___MESSAGE___", "Your message html");
    htmlContent = htmlContent.replace("___APP_ADDRESS___", ff.getHttpsAppAddress());
    htmlContent = htmlContent.replace("___BASE_URL___", ff.getHttpsAppAddress());
    htmlContent = htmlContent.replace("___SUCCESS_ADDRESS___", ff.getHttpsAppAddress() + "/application.html");
    htmlContent = '' + htmlContent;
    r.result = htmlContent;
    r.statusMessage = "User now activated";
    r.mimeType = "text/html";
}