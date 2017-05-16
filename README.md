![chef knife](logo.png)

# Gyutou

A [gyutou is a versatile chef's knife](http://korin.com/Knives/Style-Gyutou_2).

The chef-provided [command-line tool](https://docs.chef.io/knife.html) is named `knife`.

## Including in your project

### Swift Package Manager

This should work if you add it to your `Package.swift`.

### Carthage

Add this to your `Cartfile`:

```
github "Yasumoto/Gyutou" "master"
```

Then since this is a SwiftPM package, you need to create the `.xcodeproj` and add the framework:

```
cd ./Carthage/Checkouts/Gyutou/
swift package generate-xcodeproj
cd ../../..
carthage build
```

Then in your project, add your library [per the Carthage docs](https://github.com/Carthage/Carthage#getting-started).
