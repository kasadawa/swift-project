import Foundation
import Darwin
import Cocoa



// extend replace first occurence
public extension String {
  func replaceFirstOccurence(target: String, withString : String) -> String {
    if let range = self.range(of: target) {
      return self.replacingCharacters(in: range, with: withString)
    }
    return self
  }
}


// extend convert Array[String] to Dictionary<String,String>()
public extension Array where Element == String{
  func convertToDicionary() -> [String: String] {
    var dic: [String: String] = [:]
    for item:String in self {
      let tmpItem = item.components(separatedBy:" => ")
      dic[tmpItem[0]] = tmpItem[1]
    }
    return dic
  }
}


// read  condition.txt file and convert it to Dictionary
//return a tuple with (htmlConditions, fileConditions)
func getConditions(filename: String = "conditions.txt") -> (htmlConditions: [String: String], fileConditions : [String: String] ){
  var htmlConditions: [String] = []
  var fileConditions: [String] = []
  if let path = Bundle.main.path(forResource: filename, ofType: nil) {
    do {
      let text = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
      let allConditions = text.components(separatedBy: "\n").filter {(!$0.isEmpty)}
      
      let fileIndex:Int = allConditions.index(of: "# files")!  // index of "# files" tag
      htmlConditions = Array(allConditions[0 ..< fileIndex])
      fileConditions  = Array(allConditions[fileIndex ..< allConditions.count]).filter {($0[String.Index(encodedOffset: 0)] != "#")}
      
    } catch {
      assert(false , "Failed to read text from \(filename)")
    }
  } else {
    assert(false , "Failed to load file from app bundle ")
  }
  // convert condition to Dictionary type
  return (htmlConditions: htmlConditions.convertToDicionary(),fileConditions: fileConditions.convertToDicionary())
}







let conditions  = getConditions()
let fileConditions = conditions.fileConditions
let htmlConditions = conditions.htmlConditions








// writing file to Document/projectPlayground Directory
func writeFile(text: String,fileName: String) {
  
  let dir = try? FileManager.default.url(for: .documentDirectory,
                                         in: .userDomainMask, appropriateFor: nil, create: true)
  
  // If the directory was found, we write a file to it and read it back
  if let fileURL = dir?.appendingPathComponent( "projectPlayground/" + fileName) {
    // Write to the file named Test
    do {
      try text.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
      assert(false,"Failed writing to URL: \(fileURL), Error: " + error.localizedDescription)
    }
    
  }
  
}




// JSON PArser Class
class myJSONParser {
  
  var htmlString: String = "_"
  var filename: String
  var main: Any = "" // it needs to be Main but compiler need to initialized for parseJSONFeed()
  // read the input json file and decode it
  
  
  // base structure of .json file
  struct Main : Decodable {
    let root : Root
  }
  
  struct Root : Decodable {
    let meta : [Meta]
    let ui : Ui
  }
  
  struct Meta : Decodable {
    let tag : String
    let src : String
    
    enum CodingKeys : String, CodingKey {
      case tag
      case src = "@src"
    }
    
  }
  
  struct Ui : Decodable {
    let display: Display
    let a: Anker
  }
  struct Display : Decodable {
    let p: Paragraph
    
  }
  
  struct Paragraph : Decodable {
    let  text : String
    enum CodingKeys : String, CodingKey {
      case text = "@text"
    }
  }
  
  struct Anker : Decodable {
    let href : String
    let link : String
    
    enum CodingKeys : String, CodingKey {
      case link = "@link"
      case href = "@href"
    }
    
  }
  
  
  init(filename: String = "index") {
    self.filename = filename
    
    if let path = Bundle.main.path(forResource: filename, ofType: "json") {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.main = try decoder.decode(Main.self , from: data)
      }catch {
        assert(false , "Failed to read text from " + filename + ".json")
      }
    } else {
      assert(false , "Failed to load file from app bundle ")
    }
  }
  
  
  func parseJSONFeed(){
    self.recall(passedMirror: self.main as! Main)
  }
  
  
  // recursive function that is searching in binary tree
  // its mutating htmlString
  func recall(passedMirror: Any) {
    let mirror = Mirror(reflecting: passedMirror)
    
    var leftNode: Any = " "
    var rightNode: Any = " "
    
    
    var totalHtmlTags:String = ""
    var htmlTags: String = ""
    
    for child in mirror.children {
      
      if child.label == nil { // if item is meta the label will be nil
        htmlTags = self.compareMetaCondition(item:child.value as! Meta)
        totalHtmlTags = totalHtmlTags + "\n\t" +  htmlTags
        continue
      }
      
      let item: String = child.label!
      var htmlTag: String = ""
      
      if htmlConditions[item] != nil {
        htmlTag = htmlConditions[item]!
      } else {
        break
      }
      
      
      if htmlTag.contains("@") {
        let tmpMirror = Mirror(reflecting: child.value)
        
        
        for ch in tmpMirror.children {
          htmlTag = htmlTag.replacingOccurrences(of: "@" + ch.label!, with: ch.value as! String)
        }
        
        htmlTags = "\t" +  htmlTag
        
      } else {
        htmlTags = "<" + htmlTag + ">_\n</" + htmlTag + ">"
      }
      
      totalHtmlTags += "\n" + htmlTags
      
      // if the left node is empty
      if let _ = leftNode as? String {
        leftNode = child.value
      } else {
        rightNode = child.value
      }
      
      
      
    }
    
    htmlString = htmlString.replaceFirstOccurence(target: "_", withString:  totalHtmlTags)
    
    if htmlString.contains("_") {
      
      if !(leftNode as? String == " ") {
        recall(passedMirror: leftNode)
      }
      
      if !(rightNode as? String == " ") {
        recall(passedMirror: rightNode)
      }
      
    } else {
      
      // thats our bottom of the recursion
      htmlString = htmlString.replaceFirstOccurence(target: "\n", withString:  "")
      
      let writefileName  = fileConditions[self.filename + ".json"]
      
      if writefileName != nil {
        writeFile(text: htmlString, fileName: writefileName!)
      }
    }
  }
  
  
  
  // function specially created for meta tag used in recall function
  func compareMetaCondition(item : Meta) -> String{
    //    meta.*(@tag=item && @src?=.css)
    let ext = item.src.split(separator: ".")
    let metaFormat = "meta.*(@tag=" + item.tag + " && @src?=." + ext[1] + ")"
    
    if var htmlTag = htmlConditions[metaFormat] {
      htmlTag = htmlTag.replaceFirstOccurence(target: "@src", withString: item.src)
      return htmlTag
    } else {
      // if there is no condition
      assert(false, "Invalid condition");
    }
  }
  
}






// myXMLParser class with Delegate
class myXMLParser: NSObject, XMLParserDelegate {
  
  var myParser: XMLParser!
  var filename: String
  var htmlString: String = " "
  
  init(filename: String) {
    self.filename = filename // we will use this on writing phase
    let url = Bundle.main.url(forResource: filename, withExtension: "xml")!
    myParser = XMLParser(contentsOf: url)!
    super.init()
  }
  
  func parseXMLFeed() {
    myParser.delegate = self
    myParser.parse()
  }
  
  
  func parserDidEndDocument(_ parser: XMLParser) {
    let writefileName  = fileConditions[self.filename + ".xml"]
    
    if writefileName != nil {
      writeFile(text: htmlString, fileName: writefileName!)
    }
    
  }
  
  
  //parser for <tag>
  func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String :String] = [:]) {
    
    if htmlConditions[elementName] != nil && attributeDict == [:] {
      htmlString += "<" + htmlConditions[elementName]! + ">"
    }
    
    // if there is an item tag
    if elementName == "item" {
      let ext = attributeDict["src"]!.split(separator: ".")[1]
      let template = "meta.*(@tag=" + elementName + " && @src?=." + ext + ")"
      if let condition = htmlConditions[template] {
        htmlString += condition.replacingOccurrences(of: "@src", with: attributeDict["src"]!)
      }
    }
      
      // if there is other type like <button> <p> <a>
    else if attributeDict != [:] {
      if var condition = htmlConditions[elementName] {
        for (key,value) in attributeDict {
          if condition.contains("@" + key) {
            condition = condition.replacingOccurrences(of:"@" + key , with: value)
          }
        }
        htmlString += condition
      }
    }
  }
  
  
  // addding tabs, white spaces and et.
  func parser(_ : XMLParser, foundCharacters: String) {
    htmlString += foundCharacters
  }
  
  // parser for </tag>
  func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    
    //  check if the element is a single tag
    let elem: String? = htmlConditions[elementName];
    
    if  elem != nil && !(elem!.contains("@")) {
      htmlString += "<" + elem! + ">"
    }
  }
  
}




for (key,_) in fileConditions {
  
  let ext = key.split(separator: ".")
  
  switch ext[1] {
    
  case "json":
    let instance = myJSONParser(filename: String(ext[0]))  // create the class instanse
    instance.parseJSONFeed()
    
    print("---------------------Parsing \(key)---------------------\n", instance.htmlString, "\n")
    
  case "xml":
    let instance = myXMLParser(filename: String(ext[0]))  // create the class instanse
    instance.parseXMLFeed()
    print("--------------------Parsing \(key)----------------------\n", instance.htmlString, "\n")
    
  default:
    assert(false, "Not supported parser")
  }

  
}




