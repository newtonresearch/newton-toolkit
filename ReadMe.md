#Newton Toolkit for Mac OS X (NTX)
The NTX application is intended to be a replacement for NTK.
There is still a lot of work to do! However, you can already use it as a NewtonScript playground.
Try executing the scripts in the Demo.newtonproj to get a flavour of what’s possible. (Select text, press fn-return to execute.)

By Simon Bell <simon@newtonresearch.org>.


##BUILDING
Open the NTX Xcode project. It builds for OS X 10.10, 64-bit.


##DEPENDENCIES
The interesting Newton stuff is done by the [NTK.framework](https://github.com/newtonresearch/newton-framework)
which you will need to check out separately if you want to tinker with it.
Update the reference from the NTX project to point to your copy of the NTK.framework.
If modifying the framework, life is a lot easier once you create an Xcode workspace including the two projects
so that changes to the framework are picked up automatically when you build the app.
I don’t know how to express that dependency in GitHub.

The Sparkle framework is used for automatic software update. (I am guessing this app will never be accepted in the App Store.)
It is not enabled at the moment, but...
The project assumes the Sparkle folder is at the same level as the project folder.
Either move the Sparkle folder in this repo or update its location in the project.


##File types
Files must have the appropriate extension to be recognised by NTX. (Is this really progress?)

File type | Extension
--- | ---
Project | .newtonproj
NewtonScript | .newtonscript
Layout | .newtonlayout
Stream | .newtonstream
Package | .newtonpkg
