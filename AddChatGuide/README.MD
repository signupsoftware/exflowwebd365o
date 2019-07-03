### New function: Chat
For customers running D365 ExFlow version 2.2.0 you can now enable the chat function in ExFlow Web.
To do so you must enable certain parameters in the Web.Config file of the webapp, steps to follow below.

* Go to App Services and find your webapp > Go to Advanced tool in the WebApp Blade and click "Go ->"
![kudu](/AddChatGuide/enterkudu.png)
* Go to "Debug console" > CMD/Powershell > Go down in the folderstructure: Site > wwwroot > Edit the web.config File 
![kudu](/AddChatGuide/editwebconfig.png)
* In the Editor, find "AppControlMergeFile" in the <appSettings> node and append the following string:
    * "{Labs.Vue}=true;{Labs.Vue.XChat}=true;"
    * It is important that the MergFile settings are delimited by ";" be sure to add this infront of the current last setting if not already there.
    * Example of how it should look with the default setting:
    * <add key="AppControlMergeFile" value="App.AX.WS.xml?{ax365api1}=true;{Lines.EditQty}=false;{UseDebugLog}=false;{FormsTestSite}=false;{CacheCodingOnUser}=true;{FileCacheEnabled}=false;{Lines.RemoveOrginal}=true;{Lines.ChangeType}=true;{ForwardTo}=true;{ForwardTo.NoPrevious}=true;{Lines.RemoveAll}=false;{Lang.All}=true;{Lines.UseLineTemplates}=true;{Lines.UseAsyncValidation}=true<mark>;{Labs.Vue}=true;{Labs.Vue.XChat}=true;</mark>"/>
![kudu](/AddChatGuide/editwebconfigline.png)

* Make sure to press "Save" after making changes, this will restart the site and enable the chat function.
