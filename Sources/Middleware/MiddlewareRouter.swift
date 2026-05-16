//
//  MiddlewareRouter.swift
//  Swifter
//
//  Created by Tomasz on 14/03/2025.
//
import Foundation

class MiddlewareRouter {
    private class Node {
        /// The children nodes that form the route
        var nodes = [String: Node]()

        /// Define whether or not this node is the end of a route
        var isEndOfRoute: Bool = false

        /// The closure to handle the route
        var handler: HttpMiddlewareHandler?
    }

    private var rootNode = Node()

    /// The Queue to handle the thread safe access to the routes
    private let queue = DispatchQueue(label: "swifter.httpserverio.middlewarerouter")

    var routes: [String] {
        var routes = [String]()
        for (_, child) in self.rootNode.nodes {
            routes.append(contentsOf: self.routesForNode(child))
        }
        return routes
    }

    private func routesForNode(_ node: Node, prefix: String = "") -> [String] {
        var result = [String]()
        if node.handler != nil {
            result.append(prefix)
        }
        for (key, child) in node.nodes {
            result.append(contentsOf: self.routesForNode(child, prefix: prefix + "/" + key))
        }
        return result
    }

    func register(path: String, handler: HttpMiddlewareHandler?) {
        let path = "/" + path.trimmedSlashes
        let pathSegments = self.stripQuery(path).split("/")
        var pathSegmentsGenerator = pathSegments.makeIterator()
        let node = self.inflate(self.rootNode, generator: &pathSegmentsGenerator)
        node.handler = handler
    }

    private func inflate(_ node: Node, generator: inout IndexingIterator<[String]>) -> Node {
        var currentNode = node
        while let pathSegment = generator.next() {
            if let nextNode = currentNode.nodes[pathSegment] {
                currentNode = nextNode
            } else {
                currentNode.nodes[pathSegment] = Node()
                currentNode = currentNode.nodes[pathSegment]!
            }
        }

        currentNode.isEndOfRoute = true
        return currentNode
    }

    func layers(path: String) -> [HttpMiddlewareHandler] {
        return self.queue.sync {
            let pathSegments = self.stripQuery(path).split("/")
            var pathSegmentsGenerator = pathSegments.makeIterator()
            return self.findHandler(&self.rootNode, generator: &pathSegmentsGenerator)
        }
    }

    private func findHandler(_ node: inout Node, generator: inout IndexingIterator<[String]>) -> [HttpMiddlewareHandler] {
        var matchedRoutes = [Node]()
        let pattern = generator.map { $0 }
        self.findHandler(node, pattern: pattern, matchedNodes: &matchedRoutes, index: 0)
        return matchedRoutes.compactMap {
            $0.handler
        }
    }

    private func findHandler(_ node: Node, pattern: [String], matchedNodes: inout [Node], index: Int) {
        if index < pattern.count, let pathToken = pattern[index].removingPercentEncoding {
            let currentIndex = index + 1

            if let greedyNode = node.nodes["**"] {
                if greedyNode.isEndOfRoute {
                    // ** at the end of a route works as a catch-all
                    matchedNodes.append(greedyNode)
                }
                let registeredPaths = greedyNode.nodes.keys
                if !registeredPaths.isEmpty {
                    var currentIndex = currentIndex
                    while currentIndex < pattern.count, let pathToken = pattern[currentIndex].removingPercentEncoding {
                        currentIndex += 1
                        if registeredPaths.contains(pathToken) {
                            self.findHandler(greedyNode.nodes[pathToken]!, pattern: pattern, matchedNodes: &matchedNodes, index: currentIndex)
                        }
                    }
                }
            }

            if let node = node.nodes["*"] {
                self.findHandler(node, pattern: pattern, matchedNodes: &matchedNodes, index: currentIndex)
            }

            if pathToken != "*", pathToken != "**", let node = node.nodes[pathToken] {
                self.findHandler(node, pattern: pattern, matchedNodes: &matchedNodes, index: currentIndex)
            }
        }

        if node.isEndOfRoute, index == pattern.count {
            // if it's the last element and the path to match is done then it's a pattern matching
            matchedNodes.append(node)
        }
    }

    private func stripQuery(_ path: String) -> String {
        if let path = path.components(separatedBy: "?").first {
            return path
        }
        return path
    }
}
