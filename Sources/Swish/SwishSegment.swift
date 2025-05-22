//
//  SwishSegment.swift
//  Swish
//
//  Created by Ben Nortier on 2023/04/21.
//
//  A segment of text with a start and end time in milliseconds.

public struct SwishSegment: Equatable, Hashable {

    public let t0: Int
    public let t1: Int
    public let text: String

    public init(t0: Int, t1: Int, text: String) {
        self.t0 = t0
        self.t1 = t1
        self.text = text
    }
}
