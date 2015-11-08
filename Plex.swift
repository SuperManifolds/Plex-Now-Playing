/*
    Copyright (c) 2015, Alex S. Glomsaas
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

        1. Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.

        2. Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

        3. Neither the name of the copyright holder nor the names of its
        contributors may be used to endorse or promote products derived from
        this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

class Plex: NSViewController, THOPluginProtocol {
    @IBOutlet var preferences: NSView!
    @IBOutlet var plexHostnameField: NSTextField!
    @IBOutlet var plexPortfield: NSTextField!
    
    required override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    var subscribedUserInputCommands: [AnyObject] {
        return ["plex"]
    }
    
    var pluginPreferencesPaneMenuItemName: String {
        return "Plex Now Playing"
    }
    
    var pluginPreferencesPaneView: NSView? {
        return self.preferences
    }
    
    func pluginLoadedIntoMemory() {
        let defaults: [String : AnyObject] = [
            "plexHostname": "127.0.0.1",
            "plexPort": 32400
        ]
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
        
        self.performBlockOnMainThread({
            NSBundle(forClass: object_getClass(self)).loadNibNamed("Preferences", owner: self, topLevelObjects: nil)
        })
    }
    
    func userInputCommandInvokedOnClient(client: IRCClient!, commandString: String!, messageString: String!) {
        let currentChannelAtActivation = self.masterController().mainWindow.selectedChannel
        
        let defaults = NSUserDefaults.standardUserDefaults()
        let host = defaults.stringForKey("plexHostname")!
        let port = defaults.integerForKey("plexPort")
        
        NSLog("http://\(host):\(port)/status/sessions")
        
        if let requestUrl = NSURL(string: "http://\(host):\(port)/status/sessions") {
            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
            config.HTTPAdditionalHeaders = ["Accept": "application/json"]
            
            let session = NSURLSession(configuration: config)
            session.dataTaskWithURL(requestUrl, completionHandler: {(data : NSData?, response: NSURLResponse?, error: NSError?) -> Void in
                guard data != nil else {
                    return
                }
                
                do {
                    /* Attempt to serialise the JSON results into a dictionary. */
                    let root = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as! Dictionary<String, AnyObject>
                    let sessions = root["_children"] as! [Dictionary<String, AnyObject>]
                    if sessions.count > 0 {
                        let video = sessions[0]
                        let type = video["type"] as! String
                        let elements = video["_children"] as! [Dictionary<String, AnyObject>]
                        
                        var isPaused = false
                        for element in elements {
                            if element["_elementType"] as? String == "Player" {
                                let state = element["state"] as? String
                                isPaused = state == "paused"
                            }
                        }
                        
                        switch type {
                        case "episode":
                            let showName      = video["grandparentTitle"] as! String
                            let episodeTitle  = video["title"]            as! String
                            let seasonNumber  = video["parentIndex"]      as! String
                            let episodeNumber = video["index"]            as! String
                            
                            if isPaused {
                                client.sendAction("is currently watching \(showName) Season \(seasonNumber) Episode \(episodeNumber) \"\(episodeTitle)\" on Plex (Paused)", toChannel: currentChannelAtActivation)
                            } else {
                                client.sendAction("is currently watching \(showName) Season \(seasonNumber) Episode \(episodeNumber) \"\(episodeTitle)\" on Plex", toChannel: currentChannelAtActivation)
                            }
                        case "movie":
                            let title  = video["title"]  as! String
                            let studio = video["studio"] as! String
                            let year   = video["year"]   as! String
                            
                            if isPaused {
                                client.sendAction("is currently watching \(title) (\(year)) by \(studio) on Plex (Paused)", toChannel: currentChannelAtActivation)
                            } else {
                                client.sendAction("is currently watching \(title) (\(year)) by \(studio) on Plex", toChannel: currentChannelAtActivation)
                            }
                            
                        default:
                            client.printDebugInformation("The format of the currently playing item on Plex is not currently supported.")
                        }
                    } else {
                        client.printDebugInformation("You are not currently playing anything.")
                    }
                    
                } catch {
                    return
                }
                
            }).resume()
        }
    }
    
    override func viewDidAppear() {
        let formatter = self.plexPortfield.formatter as! NSNumberFormatter
        formatter.generatesDecimalNumbers = false
        formatter.maximumFractionDigits = 0
        
        let defaults = NSUserDefaults.standardUserDefaults()
        self.plexHostnameField.stringValue = defaults.stringForKey("plexHostname")!
        self.plexPortfield.stringValue = String(defaults.integerForKey("plexPort"))
    }
    
    
    @IBAction func plexHostnameFieldChanged(sender: NSTextField) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(sender.stringValue, forKey: "plexHostname")
        defaults.synchronize()
    }
    
    @IBAction func plexPortFieldChanged(sender: NSTextField) {
        if let portNumber = Int(sender.stringValue) {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setInteger(portNumber, forKey: "plexPort")
            defaults.synchronize()
        }
    }
}