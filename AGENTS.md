Simple Swift REST server library with websockets support. Implemented as full Swift 6 structured concurrecy to work on MacOS, iOS and Linux platforms.

## Project Structure
All new classes/structs/enums put in appropriate folder in separate file. Do not create long files with multiple definitions inside. Although you can add type's extensions in the same file as extended type. If you need extend some object to protocol, name file ObjectType+ProtocolName.swift.

## Building project
Run `swift build` to build the project

## Testing
Local MacOS machine has docker running with swift:6.1 image

- Run `swift test` for unit test on local MacOS
- Run `docker run --rm -t  -v "$PWD":/workspace -w /workspace swift:6.1 swift test  --scratch-path /tmp/swifter-build-6.1 --no-parallel` for unit test on linux

## Change commit
Never commit anything, let user review changes.