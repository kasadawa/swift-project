import Foundation
import Darwin
import Cocoa



// extend replace first occurence
public extension String {
    func replaceFirstOccurence(target: String, withString replaceString: String) -> String {
        if let range = self.range(of: target) {
            return self.replacingCharacters(in: range, with: replaceString)
        }
        return self
    }
}


// extend convert Array[String] to Dictionary<String,String>()
public extension Array where Element == String{
    func convertToDicionary() -> Dictionary<String,String> {
        var dic = Dictionary<String,String>();
        for item:String in self {
            let tmpItem = item.components(separatedBy:" => ");
            dic[tmpItem[0]] = tmpItem[1];
        }
        return dic;
    }
}


// read  condition.txt file and convert it to Dictionary
//return a tuple with (htmlConditions, fileConditions)
func getConditions(filename: String = "conditions.txt") -> (htmlConditions:Dictionary<String,String>, fileConditions :Dictionary<String,String> ){
    var htmlConditions = [String]()
    var fileConditions  = [String]()
    if let path = Bundle.main.path(forResource: filename, ofType: nil) {
        do {
            let text = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
            let allConditions = text.components(separatedBy: "\n").filter {(!$0.isEmpty)};
            
            
            let fileIndex:Int = allConditions.index(of: "# files")!; // index of "# files" tag
            htmlConditions = Array(allConditions[0 ..< fileIndex]) ;
            fileConditions  = Array(allConditions[fileIndex ..< allConditions.count]).filter {($0[String.Index(encodedOffset: 0)] != "#")}
            
        } catch {
            print("Failed to read text from \(filename)")
        }
    } else {
        print("Failed to load file from app bundle ")
    }
    // convert condition to Dictionary type
    return (htmlConditions: htmlConditions.convertToDicionary(),fileConditions: fileConditions.convertToDicionary());
}







let conditions  = getConditions() ; // htmlConditions
let fileConditions = conditions.fileConditions;
let htmlConditions = conditions.htmlConditions;



















// writing file to Document/projectPlayground Directory
func writeFile(text: String,fileName: String) {
    print("creating new file")
    
    let dir = try? FileManager.default.url(for: .documentDirectory,
                                           in: .userDomainMask, appropriateFor: nil, create: true)
    
    // If the directory was found, we write a file to it and read it back
    if let fileURL = dir?.appendingPathComponent( "projectPlayground/" + fileName) {
        
        // Write to the file named Test
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed writing to URL: \(fileURL), Error: " + error.localizedDescription)
        }
        
    }
}







// JSON PArser Class
class myJSONParser {
    
    
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
    }
    struct Display : Decodable {
        let p: Button
        
    }
    
    struct Button : Decodable {
        let  text : String
        enum CodingKeys : String, CodingKey {
            case text = "@text"
        }
    }
    
    // global
    var htmlString: String = "_"
    var filename: String
    var main: Any = "" // it needs to be Main but compiler need to initialized for parseJSONFeed() 
    // read the input json file and decode it
    // return Main Struct
    init(filename: String = "index"){
        self.filename = filename
    
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                self.main = try decoder.decode(Main.self , from: data)
            }catch {
                print("Failed to read text from " + filename + ".json")
            }
        } else {
            print("Failed to load file from app bundle ")
        }
    }

    
    func parseJSONFeed(){
        self.recall(passedMirror: self.main as! Main)
    }
    
    // recursive function that is searching in binary tree
    // its mutating htmlString
    func recall(passedMirror: Any) {
        let mirror = Mirror(reflecting: passedMirror);
        
        var leftNode: Any = " "
        var rightNode: Any = " "
        
        
        var totalHtmlTags:String = ""
        var htmlTags: String = ""
        
        for child in mirror.children {
            var item:String
            
            if(child.label == nil){ // if item is meta the label will be nil
                htmlTags = self.compareMetaCondition(item:child.value as! Meta);
                totalHtmlTags = totalHtmlTags + "\n\t" +  htmlTags;
                continue;
            }else{
                item = child.label! ;
            }
            
            let htmlTag:String = htmlConditions[item]!
            if( htmlTag.contains("@")){
                let tmpMirror = Mirror(reflecting: child.value);
                for ch in tmpMirror.children{
                    let tmp:String = ch.label!
                    htmlTags = "\t" + htmlTag.replacingOccurrences(of: "@" + tmp, with: ch.value as! String)
                }
                
            }else{
                htmlTags = "<" + htmlTag + ">_\n</" + htmlTag + ">";
            }
            
            if let _ = leftNode as? String { // if the left node is empty
                leftNode = child.value
            }else{
                rightNode = child.value
            }
            
            totalHtmlTags += "\n" + htmlTags;
            
        }
        
        self.htmlString = self.htmlString.replaceFirstOccurence(target: "_", withString:  totalHtmlTags)
        
        if self.htmlString.contains("_") { // thats our bottom of the recursion
            
            if !(leftNode as? String == " " ){
                //                print("leftNode:    " , leftNode)
                recall(passedMirror: leftNode)
            }
            if !(rightNode as? String == " " ){
                //                print("rightNode:    " , rightNode)
                recall(passedMirror: rightNode)
            }
            
        }else{
            
            self.htmlString = self.htmlString.replaceFirstOccurence(target: "\n", withString:  "")
 
            if fileConditions[self.filename + ".json"] != nil{
                let writefileName  = fileConditions[self.filename + ".json"]
                writeFile(text: self.htmlString,fileName: writefileName!);
            }
        }
    }
    
    
    
    // function specially created for meta tag used in recall function
    func compareMetaCondition(item : Meta)-> String{
        //    meta.*(@tag=item && @src?=.css)
        var ext = item.src.split(separator: ".");
        let metaFormat = "meta.*(@tag=" + item.tag + " && @src?=." + ext[1] + ")" ;
        
        if var htmlTag = htmlConditions[metaFormat] { // if there is no condition
            htmlTag = htmlTag.replaceFirstOccurence(target: "@src", withString: item.src)
            return htmlTag;
        }
        else{
            print("Invalid condition")
        }
        return "nil"
    }
    
}






// myXMLParser class with Delegate

class myXMLParser: NSObject,XMLParserDelegate {

    var myParser: XMLParser!
    var filename: String
    var htmlString : String = " "

    init(filename: String) {
        self.filename = filename // we will use this on writing phase
        let url = Bundle.main.url(forResource: filename, withExtension: "xml")!
        myParser = XMLParser(contentsOf: url)!
        super.init()
    }

    func parseXMLFeed() {
//        print("STARTING XML FILE PARSING")
        myParser.delegate = self
        myParser.parse()
//        print("ENDED XML FILE PARSING")
    }
    
    
    func parserDidStartDocument(_ parser: XMLParser) {
//          print("XML Document Start")
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
//        print("XML Document End, saving to document")
        
        if fileConditions[self.filename + ".xml"] != nil{
            let writefileName  = fileConditions[self.filename + ".xml"]
             writeFile(text: self.htmlString,fileName: writefileName!);
        }
       
    }
    
    
    //parser for <tag>
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: [String :String] = [:]) {

        if htmlConditions[elementName] != nil && attributeDict == [:]{
            self.htmlString += "<" + htmlConditions[elementName]! + ">";
        }
        
        // if there is an item tag
        if elementName == "item"{
            let ext = attributeDict["src"]!.split(separator: ".")[1];
            let template = "meta.*(@tag=" + elementName + " && @src?=." + ext + ")" ;
            if let condition = htmlConditions[template] {
                self.htmlString += condition.replacingOccurrences(of: "@src", with: attributeDict["src"]!)
            }
        }
        // if there is other type like button or paragraf
        else if(attributeDict != [:]){
            if let condition = htmlConditions[elementName]{
                for (key,value) in attributeDict{
                    if condition.contains("@" + key){
                       self.htmlString += condition.replacingOccurrences(of:"@" + key , with: value)
                    }
                }
            }
        }
    }
    
    
    // addding tabs, white spaces and et.
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.htmlString += string ;
    }

    // parser for </tag>
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        //  check if the element is a single tag
        if htmlConditions[elementName] != nil && !(htmlConditions[elementName]!.contains("@")) {
            self.htmlString += "<" + htmlConditions[elementName]! + ">";
        }
    }
    
}




for (key,value) in fileConditions {
    
    let ext = key.split(separator: ".")
    
    if ext[1] == "json" {
        let instance = myJSONParser(filename:String(ext[0])); // create the class instanse
        instance.parseJSONFeed();
        print("---------------------Parsing \(key)---------------------\n",instance.htmlString,"\n");
    }
    
    if ext[1] == "xml" {
        let instance = myXMLParser(filename:String(ext[0])); // create the class instanse
        instance.parseXMLFeed();
        print("--------------------Parsing \(key)----------------------\n", instance.htmlString,"\n");
    }
    
    


    
}




