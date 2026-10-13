#!/usr/bin/env python3
"""iOS build step: adds the alternate app icons and the small native plugin that switches between them.

Run after `npx cap add ios`. Icons come from ios-assets/alt/icon-<name>-1024.png. Prints warnings instead of
failing if the Capacitor template layout changed, in which case the game simply hides its icon picker.
"""
import json
import os
import re
import shutil

ICONS = ['slime', 'moon', 'zombie', 'soldier', 'classic']
NAMES = {i: 'ZSIcon' + i.capitalize() for i in ICONS}
ASSETS = 'ios/App/App/Assets.xcassets'

for key, name in NAMES.items():
    d = f'{ASSETS}/{name}.appiconset'
    os.makedirs(d, exist_ok=True)
    src = f'ios-assets/alt/icon-{ {"moon":"blood-moon","classic":"classic-hand"}.get(key, key) }-1024.png'
    shutil.copy(src, f'{d}/icon.png')
    json.dump(
        {
            'images': [{'filename': 'icon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
            'info': {'author': 'xcode', 'version': 1},
        },
        open(f'{d}/Contents.json', 'w'),
        indent=2,
    )
print('Alternate icon sets:', ' '.join(NAMES.values()))

swift = '''

@objc(AppIconPlugin)
public class AppIconPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AppIconPlugin"
    public let jsName = "AppIcon"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "get", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "set", returnType: CAPPluginReturnPromise),
    ]
    @objc func get(_ call: CAPPluginCall) {
        call.resolve(["name": UIApplication.shared.alternateIconName ?? ""])
    }
    @objc func set(_ call: CAPPluginCall) {
        let wanted = call.getString("name") ?? ""
        let name: String? = wanted.isEmpty ? nil : wanted
        DispatchQueue.main.async {
            UIApplication.shared.setAlternateIconName(name) { error in
                if let error = error { call.reject(error.localizedDescription) } else { call.resolve() }
            }
        }
    }
}

@objc(ZSBridgeViewController)
class ZSBridgeViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(AppIconPlugin())
    }
}
'''
p = 'ios/App/App/AppDelegate.swift'
s = open(p).read()
if 'AppIconPlugin' not in s:
    if 'import Capacitor' not in s:
        s = s.replace('import UIKit', 'import UIKit\nimport Capacitor', 1)
    open(p, 'w').write(s + swift)

sb = 'ios/App/App/Base.lproj/Main.storyboard'
t = open(sb).read()
new, n = re.subn(
    r'customClass="CAPBridgeViewController"(\s+customModule=")Capacitor(")',
    r'customClass="ZSBridgeViewController"\1App\2',
    t,
)
if n:
    open(sb, 'w').write(new)
    print('Storyboard now uses ZSBridgeViewController')
else:
    print('::warning::Main.storyboard layout changed; the app icon picker will be unavailable')
