class SM64Program extends WinGameProgram {
    _launch(game, args*) {
        startDelfinovin()
        super._launch(game, args*)
    }

    _postExit() {
        stopDelfinovin()
    }
}