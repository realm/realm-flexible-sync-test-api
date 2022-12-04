![Realm](https://github.com/realm/realm-dart/raw/main/logo.png)

## Description

This repo contains two Sample Apps which use different proposed APIs for flexible sync.
The purpose of this repo is to A/B Test this APIs. 

The Realm Swift SDK is located at https://github.com/realm/realm-swift

## Usage
- Install the application following the instructions in the next section.
- Check the README.md files of each sample app for instructions on how to install and use each of the APIs.

## Building and running the app

1. If you don't already have one [create a MongoDB Atlas Account](https://cloud.mongodb.com/), and cluster.
1. Install the [Realm CLI](https://docs.mongodb.com/realm/deploy/realm-cli-reference) and [create an API key pair](https://docs.atlas.mongodb.com/configure-api-access#programmatic-api-keys).
1. Download the repo and install the Realm app:
```ruby
git clone https://github.com/realm/realm-flexible-sync-test-api.git
cd realm-flexible-sync-test-api/trail_tracker_app
realm-cli login --api-key <your new public key> --private-api-key <your new private key>
realm-cli import # Then answer prompts, naming the app TrailTrackerApp
```
4. From the Atlas UI, click on the Realm logo and you will see the TrailTrackerApp app. Open it and copy the App Id.

Or follow the instructions on the [documentation](https://www.mongodb.com/docs/atlas/app-services/sync/data-access-patterns/flexible-sync/) to create it manually.
