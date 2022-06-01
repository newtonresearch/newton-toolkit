Newton Toolkit for Mac OS X (NTX)
====
The NTX application is intended to be a replacement for NTK.
There is still a lot of work to do! However, you can already use it as a NewtonScript playground.
Try executing the scripts in the Demos folder to get a flavour of what’s possible. (Select text, press fn-return to execute.)


BUILDING
----
Open the NTX Xcode 8 project. It builds for macOS Sierra, 64-bit.


DEPENDENCIES
----
The interesting Newton stuff is done by the [NTK.framework](https://github.com/newtonresearch/newton-framework)
which you will need to check out separately if you want to tinker with it.
Update the reference from the NTX project to point to your copy of the NTK.framework.
If modifying the framework, life is a lot easier once you create an Xcode workspace including the two projects
so that changes to the framework are picked up automatically when you build the app.
I don’t know how to express that dependency in GitHub.


File types
----
Files must have the appropriate extension to be recognised by NTX.

File type | Extension
--- | ---
Project | .newtonproj
NewtonScript | .newtonscript
Layout | .newtonlayout
Stream | .newtonstream
Package | .newtonpkg
