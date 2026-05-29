Simple Swift REST server library with websockets support. Implemented as full Swift 6 structured concurrecy to work on MacOS, iOS and Linux platforms.

## Project Structure
All new classes/structs/enums put in appropriate folder in separate file. Do not create long files with multiple definitions inside. Although you can add type's extensions in the same file as extended type. If you need extend some object to protocol, name file ObjectType+ProtocolName.swift.

## Building project
Run `swift build` to build the project

## Testing
Local MacOS machine has docker running with swift:6.0, 6.1 and 6.2 image

- Run `swift test --no-parallel` for unit test on local MacOS
- Run `docker run --rm -t  -v "$PWD":/workspace -w /workspace swift:6.0 timeout 60s swift test  --scratch-path /tmp/swifter-build-6.0 --no-parallel` for unit test on linux with Swift 6.0
After work is done verify with Swift 6.1 and 6.2 as well.

## Change commit
Never commit anything, let user review changes.