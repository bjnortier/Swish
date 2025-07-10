//
//  Test.swift
//  Swish
//
//  Created by Ben Nortier on 2025/06/02.
//

import Testing

struct Segment {
    let t0: Int
    let text: String
}

class UnSendable {
    var x: Int

    init(x: Int) {
        self.x = x
    }
}

actor Foo {
    let segments: [Segment]

    init(segments: [Segment]) {
        self.segments = segments
    }
}

actor Bar {
    var y: Int

    init() {
        self.y = 3
    }

    func doSomething(segments: [Segment]) async {
        print("Doing something with \(segments.count) segments")
    }

    func doSomethingWithUnSendable(_ unSendable: UnSendable) async {
        print("Doing something with UnSendable with x = \(unSendable.x)")
        unSendable.x = self.y
    }
}

struct Test {

    //    @Test func testSendable() async throws {
    //        let segments = [Segment(t0: 0, text: "123")]
    //        let foo = Foo(segments: segments)
    //        let bar = Bar()
    //        let us = UnSendable(x: 5)
    //        await bar.doSomething(segments: foo.segments)
    //        await bar.doSomethingWithUnSendable(us)
    //        print(us.x)
    //    }

}
