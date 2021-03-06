import Vapor
import Fluent

/**
    Converts a Fluent Query into a RESTful request.
*/
public class RESTDriver: DatabaseDriver {
    public let idKey = "id"
    public let url: String
    public let drop: Droplet

    public init(url: String, drop: Droplet) {
        self.url = url
        self.drop = drop
    }

    public func query<T: Fluent.Model>(_ query: Query<T>) throws -> [[String: Fluent.Value]] {
        switch query.action {
        case .fetch:
            var id: String? = nil

            var q: [String: CustomStringConvertible] = [:]

            for filter in query.filters {
                switch filter {
                case .compare(let key, let comp, let val):
                    if comp == .equals {
                        if key == idKey {
                            id = val.string
                        } else {
                            q[key] = val.string ?? ""
                        }
                    }
                default:
                    break
                }
            }

            if let id = id {
                return try get("\(url)/\(query.entity)/\(id)", query: q)
            } else {
                return try get("\(url)/\(query.entity)", query: q)
            }
        default:
            return []
        }
    }

    public func schema(_ schema: Schema) throws {
        // nothing
    }

    private func parseObject(_ object: [String: JSON]) -> [String: Fluent.Value] {
        var parsed: [String: Fluent.Value] = [:] // FIXME: Node

        for (key, value) in object {
            switch value {
            case .string(let string):
                parsed[key] = string
            case .number(let number):
                switch number {
                case .integer(let int):
                    parsed[key] = int
                case .double(let double):
                    parsed[key] = double
                case .unsignedInteger(let uint):
                    parsed[key] = Int(uint)
                }
            default:
                drop.console.warning("Didn't parse value: \(key): \(value)")
                break
            }
        }

        return parsed
    }

    private func get(_ address: String, query: [String: CustomStringConvertible]) throws -> [[String: Fluent.Value]] {
        drop.log.info(address)
        let response = try drop.client.get(address, query: query)

        if let json = response.json {
            switch json {
            case .array(let array):
                let parsed: [[String: FluentValue]] = array.flatMap { json in
                    switch json {
                    case .object(let object):
                        return parseObject(object)
                    default:
                        return nil
                    }
                }

                return parsed
            case .object(let object):
                return [parseObject(object)]
            default:
                drop.log.warning("Response was neither array nor object.")
                return []
            }
        } else {
            drop.log.warning("Response was not JSON.")
            return []
        }
    }
}
