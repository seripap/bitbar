import FootlessParser
import Foundation
import PathKit
import Dollar

enum Metadata: CustomStringConvertible {
  private typealias P<T> = Parser<Character, T>
  private static let start = "<bitbar."
  private static let trash = til(start, allowEmpty: true, consume: false)

  case about(URL)
  case image(URL)
  case title(String)
  case github(String)
  case author(String)
  case version(String)
  case description(String)
  case dependencies([String])
  case dropTypes([String])
  case demoArgs([String])

  init?(key: String, value: String) {
    switch key.lowercased() {
    case "title":
      self = .title(value)
    case "version":
      self = .version(value)
    case "author.github":
      self = .github(value)
    case "author":
      self = .author(value)
    case "desc":
      self = .description(value)
    case "image":
      if let url = URL(string: value) {
        self = .image(url)
      } else {
        return nil
      }
    case "dependencies":
      self = .dependencies(value.split(delimiter: ",").map { $0.trimmed() })
    case "droptypes":
      self = .dropTypes(value.split(delimiter: ",").map { $0.trimmed() })
    case "demo":
      self = .demoArgs(value.split(delimiter: " ").map { $0.trimmed() })
    case "abouturl":
      if let url = URL(string: value) {
        self = .about(url)
      } else {
        return nil
      }
    default:
      return nil
    }
  }

  public var description: String {
    switch self {
    case let .title(title):
      return "Title: \(title)"
    case let .version(version):
      return "Version: \(version)"
    case let .github(value):
      return "Github: \(value)"
    case let .author(value):
      return "Author: \(value)"
    case let .description(value):
      return "Description: \(value)"
    case let .image(value):
      return "Image: \(value)"
    case let .dependencies(value):
      return "Dependencies: \(value.joined(separator: ", "))"
    case let .dropTypes(value):
      return "Drop types: \(value.joined(separator: ", "))"
    case let .demoArgs(value):
      return "Demo Args: \(value.joined(separator: ", "))"
    case let .about(url):
      return "About: \(url.absoluteString)"
    }
  }

  public enum Result {
    case failure([String])
    case success([Metadata])
  }

  private static var parser: P<[Metadata]> {
    return oneOrMore(trash *> item <* trash) <|> (zeroOrMore(any()) *> pure([]))
  }

  static func from(path: String) throws -> [Metadata] {
    return try FootlessParser.parse(parser, try Path(path).read())
  }

  // TODO: Dont use this method in MetadataTests
  internal static func parse(_ value: String) -> Result {
    do {
      return Result.success(try FootlessParser.parse(parser, value))
    } catch ParseError<Character>.Mismatch(let remainder, let expected, let actual) {
      let index = value.index(value.endIndex, offsetBy: -Int(remainder.count))
      let (lineRange, row, pos) = position(of: index, in: value)
      let line = value[lineRange.lowerBound..<lineRange.upperBound].trimmingCharacters(in: CharacterSet.newlines)
      var lines = [String]()
      lines.append("An error occurred when parsing this line:")
      lines.append(line)
      lines.append(String(repeating: " ", count: pos) + "^")
      lines.append("\(row):\(pos) Expected '\(expected)', actual '\(actual)'")
      return Result.failure(lines)
    } catch (let error) {
      return Result.failure([String(describing: error)])
    }
  }

  private static func position(of index: String.CharacterView.Index, in string: String) -> (line: Range<String.CharacterView.Index>, row: Int, pos: Int) {
    var head = string.startIndex..<string.startIndex
    var row = 0
    while head.upperBound < index {
        head = string.lineRange(for: head.upperBound..<head.upperBound)
        row += 1
    }
    return (head, row, string.distance(from: head.lowerBound, to: index))
  }

  private static var item: P<Metadata> {
    return string(start) *> til(">") >>- { type in
      return til("</bitbar.\(type)>", allowEmpty: true) >>- { value in
        if let metadata = Metadata(key: type, value: value.trimmed()) {
          return pure(metadata)
        }
        return stop("Could not find any type matching \(type) & \(value)")
      }
    }
  }

  private static func til(_ value: String, allowEmpty: Bool = false, consume: Bool = true) -> P<String> {
    let none = noneOf([value])
    let par = allowEmpty ? zeroOrMore(none) : oneOrMore(none)

    if consume {
      return par <* optional(string(value))
    }

    return par
  }

  private static func stop<A, B>(_ message: String) -> Parser<A, B> {
    return Parser { parsedtokens in
      throw ParseError.Mismatch(parsedtokens, message, "done")
    }
  }
}
