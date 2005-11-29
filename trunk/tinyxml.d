/*
    tinyxml for D 
    Under GPL 
    
    www.sourceforge.net/projects/tinyxml
    Original code (2.0 and earlier ) copyright (c) 2000-2002 Lee Thomason (www.grinninglizard.com)
    
    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any
    damages arising from the use of this software.
    
    Permission is granted to anyone to use this software for any
    purpose, including commercial applications, and to alter it and
    redistribute it freely, subject to the following restrictions:
    
    1. The origin of this software must not be misrepresented; you must
    not claim that you wrote the original software. If you use this
    software in a product, an acknowledgment in the product documentation
    would be appreciated but is not required.
    
    2. Altered source versions must be plainly marked as such, and
    must not be misrepresented as being the original software.
    
    3. This notice may not be removed or altered from any source
    distribution.
*/

module tinyxml;

/+
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// debug = TI_DEBUG

#if defined( DEBUG ) && defined( _MSC_VER )
#include <windows.h>
#define TIXML_LOG OutputDebugString
#else
#define TIXML_LOG printf
#endif

#include "tinystr.h"
#define TIXML_STRING    TiXmlString
#define TIXML_OSTREAM   TiXmlOutStream

+/
alias char[] string;

//class TiXmlDocument;
//class TiXmlElement;
//class TiXmlComment;
//class TiXmlUnknown;
//class TiXmlAttribute;
//class TiXmlText;
//class TiXmlDeclaration;
//class TiXmlParsingData;

const int TIXML_MAJOR_VERSION = 2;
const int TIXML_MINOR_VERSION = 4;
const int TIXML_PATCH_VERSION = 2;


// Bunch of unicode info at:
//      http://www.unicode.org/faq/utf_bom.html
// Including the basic of this table, which determines the #bytes in the
// sequence from the lead byte. 1 placed for invalid sequences --
// although the result will be junk, pass it through as much as possible.
// Beware of the non-characters in UTF-8:   
//              ef bb bf (Microsoft "lead bytes")
//              ef bf be
//              ef bf bf 

const char TIXML_UTF_LEAD_0 = 0xefU;
const char TIXML_UTF_LEAD_1 = 0xbbU;
const char TIXML_UTF_LEAD_2 = 0xbfU;

/*  Internal structure for tracking location of items 
    in the XML file.
*/
struct TiXmlCursor
{
    this()
    {
        Clear();
    }
    
    void Clear()
    {
        row = -1;
        col = -1;
    }

    int row;    // 0 based.
    int col;    // 0 based.
}


// Only used by Attribute::Query functions
enum 
{ 
    TIXML_SUCCESS,
    TIXML_NO_ATTRIBUTE,
    TIXML_WRONG_TYPE
}


// Used by the parsing routines.
enum TiXmlEncoding
{
    TIXML_ENCODING_UNKNOWN,
    TIXML_ENCODING_UTF8,
    TIXML_ENCODING_LEGACY
}

const TiXmlEncoding TIXML_DEFAULT_ENCODING = TIXML_ENCODING_UNKNOWN;

/** TiXmlBase is a base class for every class in TinyXml.
    It does little except to establish that TinyXml classes
    can be printed and provide some utility functions.

    In XML, the document and elements can contain
    other elements and other types of nodes.

    @verbatim
    A Document can contain: Element (container or leaf)
                            Comment (leaf)
                            Unknown (leaf)
                            Declaration( leaf )

    An Element can contain: Element (container or leaf)
                            Text    (leaf)
                            Attributes (not on tree)
                            Comment (leaf)
                            Unknown (leaf)

    A Decleration contains: Attributes (not on tree)
    @endverbatim
*/
abstract class TiXmlBase
{
public:
    this(){ userData = null; }  

    /** All TinyXml classes can print themselves to a filestream.
        This is a formatted print, and will insert tabs and newlines.
        
        (For an unformatted stream, use the << operator.)
    */
    abstract void Print( FILE* cfile, int depth );

    /** Return the position, in the original source file, of this node or attribute.
        The row and column are 1-based. (That is the first row and first column is
        1,1). If the returns values are 0 or less, then the parser does not have
        a row and column value.

        Generally, the row and column value will be set when the TiXmlDocument::Load(),
        TiXmlDocument::LoadFile(), or any TiXmlNode::Parse() is called. It will NOT be set
        when the DOM was created from operator>>.

        The values reflect the initial load. Once the DOM is modified programmatically
        (by adding or changing nodes and attributes) the new values will NOT update to
        reflect changes in the document.

        There is a minor performance cost to computing the row and column. Computation
        can be disabled if TiXmlDocument::SetTabSize() is called with 0 as the value.

        @sa TiXmlDocument::SetTabSize()
    */
    int Row()
    {
        return location.row + 1; 
    }
    int Column() { return location.col + 1; }   ///< See Row()

    void  SetUserData( void* user )         { userData = user; }
    void* GetUserData()                     { return userData; }

    abstract TiString Parse(TiString p, TiXmlParsingData* data, TiXmlEncoding encoding /*= TIXML_ENCODING_UNKNOWN */ );

    enum
    {
        TIXML_NO_ERROR = 0,
        TIXML_ERROR,
        TIXML_ERROR_OPENING_FILE,
        TIXML_ERROR_OUT_OF_MEMORY,
        TIXML_ERROR_PARSING_ELEMENT,
        TIXML_ERROR_FAILED_TO_READ_ELEMENT_NAME,
        TIXML_ERROR_READING_ELEMENT_VALUE,
        TIXML_ERROR_READING_ATTRIBUTES,
        TIXML_ERROR_PARSING_EMPTY,
        TIXML_ERROR_READING_END_TAG,
        TIXML_ERROR_PARSING_UNKNOWN,
        TIXML_ERROR_PARSING_COMMENT,
        TIXML_ERROR_PARSING_DECLARATION,
        TIXML_ERROR_DOCUMENT_EMPTY,
        TIXML_ERROR_EMBEDDED_NULL,
        TIXML_ERROR_PARSING_CDATA,

        TIXML_ERROR_STRING_COUNT
    }

protected:
    // See STL_STRING_BUG
    // Utility class to overcome a bug.
    class StringToBuffer
    {
      public:
        StringToBuffer( const TIXML_STRING& str);
        ~StringToBuffer();
        char* buffer;
    }

    TiXmlCursor location;

    /// Field containing a generic user pointer
    void* userData;
    
private:

    struct Entity
    {
        char[] str;
        int             strLength;
        char            chr;
    }
    enum
    {
        NUM_ENTITY = 5,
        MAX_ENTITY_LENGTH = 6

    }   
    
    static Entity entity[ NUM_ENTITY ]
    [
        { "&amp;",  5, '&' },
        { "&lt;",   4, '<' },
        { "&gt;",   4, '>' },
        { "&quot;", 6, '\"' },
        { "&apos;", 6, '\'' }
    ];
    static bool condenseWhiteSpace = true;
    
public:    
    // Table that returs, for a given lead byte, the total number of bytes
    // in the UTF-8 sequence.
    static int utf8ByteTable[256] = [
    //  0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x00
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x10
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x20
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x30
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x40
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x50
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x60
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x70 End of ASCII range
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x80 0x80 to 0xc1 invalid
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0x90 
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0xa0 
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 0xb0 
        1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  // 0xc0 0xc2 to 0xdf 2 byte
        2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  // 0xd0
        3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  // 0xe0 0xe0 to 0xef 3 byte
        4,  4,  4,  4,  4,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1   // 0xf0 0xf0 to 0xf4 4 byte, 0xf5 and higher invalid
    ];

    /** The world does not agree on whether white space should be kept or
        not. In order to make everyone happy, these global, static functions
        are provided to set whether or not TinyXml will condense all white space
        into a single space or not. The default is to condense. Note changing this
        values is not thread safe.
    */
    static void SetCondenseWhiteSpace( bool condense ){ condenseWhiteSpace = condense; }

    /// Return the current white space setting.
    static bool IsWhiteSpaceCondensed() { return condenseWhiteSpace; }  
    
    
    
protected:
    static bool isUTF8LeadingBytes(char[] p)
    {
        const char[] ms =  "\xef\xbb\xbf"; // the stupid Microsoft UTF-8 Byte order marks
        const char[] big = "\xef\xbf\xbe"; // 
        const char[] lt =  "\xef\xbf\xbf"; //
        
        return (p == ms || p == big || p == lt);            
    }
    
    static char[] SkipWhiteSpace(char[] p, TiXmlEncoding encoding )
    {
        if ( p is null || p.length == 0 )
        {
            return null;
        }
        
        if ( encoding == TIXML_ENCODING_UTF8 )
        {
            if((isUTF8LeadingBytes(p[0..3]))
            {
                p = p[3 + $];
            }
        }

        foreach(int i, dchar c; p)
        {
            if(!(std.string.isspace(c))
            {
                return p[i..$];
            }               
        }
    
        return null;
    }

    alias std.string.isspace IsWhiteSpace;  
    
    /*  Reads an XML name into the string provided. Returns
        a pointer just past the last character of the name,
        or 0 if the function has an error.
    */
    static char[] ReadName(char[] p, out char[] name, TiXmlEncoding encoding)
    in
    {
        assert( p !is null)
    }
    body
    {
        // Names start with letters or underscores.
        // Of course, in unicode, tinyxml has no idea what a letter *is*. The
        // algorithm is generous.
        //
        // After that, they can be letters, underscores, numbers,
        // hyphens, or colons. (Colons are valid ony for namespaces,
        // but tinyxml can't tell namespaces from names.)
        if (p.length > 0 && ( IsAlpha( p[0], encoding) || p[0] == '_' ))
        {
            foreach(int i, dchar c; p[1..$])
            {
                if(!(IsAlphaNum(c , encoding) 
                             || c == '_'
                             || c == '-'
                             || c == '.'
                             || c == ':'))
                {
                    name = [0..i];
                    return p[i..$];
                }               
            }
            name = p;
            return null;
        }
        name = null;
        return null;
    }

    int findTag(char[] s, char[] tag, bool ignoreCase)
    {
        if(ignoreCase)
            return std.string.ifind(p, endTag);
        else
            return std.string.find(p, endTag);

    }

    /*  Reads text. Returns a pointer past the given end tag.
        Wickedly complex options, but it keeps the (sensitive) code in one place.
    */
    static char[] ReadText(char[] p,                // where to start
                            out char[] text,            // the string read
                            bool ignoreWhiteSpace,      // whether to keep the white space
                            char[] endTag,          // what ends this text
                            bool ignoreCase,            // whether to ignore case in the end tag
                            TiXmlEncoding encoding )    // the current encoding
    {
        int idx = findTag(p, endTag, ignoreCase);
        if(idx == -1)
        {
            return null;
        }

        char[] theText = p[0 .. idx];

        if (!ignoreWhiteSpace           // certain tags always keep whitespace
             || !condenseWhiteSpace )   // if true, whitespace is always kept
        {
            // Keep all the white space.            
            while(theText.length > 0)
            {
                int len;
                char cArr[];
                theText = GetChar( p, cArr, len, encoding );
                text ~= cArr;
            }
        }
        else
        {
            bool whitespace = false;
    
            // Remove leading white space:
            theText = SkipWhiteSpace( theText, encoding );

            while (theText.length > 0)
            {
                if ( theText[0] == '\r' || theText[0] == '\n' )
                {
                    whitespace = true;
                    theText = theText[1 .. $];
                }
                else if ( IsWhiteSpace( theText[0] ) )
                {
                    whitespace = true;
                    theText = theText[1 .. $];
                }
                else
                {
                    // If we've found whitespace, add it before the
                    // new character. Any whitespace just becomes a space.
                    if ( whitespace )
                    {
                        text ~= ' ';
                        whitespace = false;
                    }

                    int len;
                    char cArr[];
                    theText = GetChar( p, cArr, len, encoding );
                    text ~= cArr;
                }
            }
        }

        return p[idx + endTag.length .. $];
    }                               

    // If an entity has been found, transform it into a character.
    static char[] GetEntity( char[] p, out char[] value, out int length, TiXmlEncoding encoding )
    {
        // Presume an entity, and pull it out.
    
        if ( p.length > 2 && p[1] == '#') //&#number;
        {
            int ucs = 0;
    
            if ( p[2] == 'x' )
            {
                // Hexadecimal. &#xA9;
                if ( p.length < 4 ) return null;

                int end = find(p, ';');
                if ( end == -1 )  return null;
                char[] number = p[3, end];

                foreach(char c; number)
                {
                    int value = std.string.ifind(std.string.hexdigits, c);
                    if(value == -1) return null;
                    ucs += value;
                    ucs << 4; //ucs * 16;
                }
                p = p[end + 1, $]; //skip ';'
            }
            else
            {
                // Decimal.
                if ( p.length < 3 ) return null;

                int end = find(p, ';');
                if ( end == -1 )  return null;

                char[] number = p[2, end];
    
                foreach(char c; number)
                {
                    int value = std.string.ifind(std.string.digits, c);
                    if(value == -1) return null;
                    ucs += value;
                    ucs *= 10;
                }
                p = p[end + 1, $]; //skip ';'
            }

            if ( encoding == TIXML_ENCODING_UTF8 )
            {
                // convert the UCS to UTF-8
                value = std.utf.toUTF8(cast(dchar)ucs);                
            }
            else
            {
                value.length = 1;
                value[0] = cast(char)ucs;                
            }
            return p;
        }
    
        // Now try to match it.
        foreach(Entity e; entity)
        {
            if ( e.str == p[0 .. e.strLength])
            {
                value.length = 1;
                value[0] = e.chr;                
                return p[e.strLength .. $];
            }
        }
        
        // So it wasn't an entity, its unrecognized, or something like that.
        value.length = 1;
        value[0] = p[0];    // Don't put back the last one, since we return it!
        return p[1 .. 0];
    }

    // Get a character, while interpreting entities.
    // The length can be from 0 to 4 bytes.
    static char[] GetChar( char[] p, out char[] _value, out int length, TiXmlEncoding encoding )
    in
    {
        assert( p !is null);
    }
    body
    {        
        if ( encoding == TIXML_ENCODING_UTF8 )
        {
            length = utf8ByteTable[ cast(int)p[0] ];
            assert( length >= 0 && length < 5 );
        }
        else
        {
            length = 1;
        }

        if ( length == 1 && p[0] == '&') //&0x...;
        {
            return GetEntity( p, _value, length, encoding);
        }
        
        if ( length > 0 )
        {              
            _value = p[i..length];
            return p[length .. $];
        }
        else
        {
            // Not valid text.
            return null;
        }
    }

    // Note this should not contian the '<', '>', etc, or they will be transformed into entities!
    static void PutString( char[] from, out char[] to )
    {
        foreach(int i, char c; from)
        {
            if (c == '&' && i < (str.length - 2) && from[i + 1] == '#' && from[i+2] == 'x')
            {
                // Hexadecimal character reference.
                // Pass through unchanged.
                // &#xA9;   -- copyright symbol, for example.
                //
                // The -1 is a bug fix from Rob Laveaux. It keeps
                // an overflow from happening if there is no ';'.
                // There are actually 2 ways to exit this loop -
                // while fails (error case) and break (semicolon found).
                // However, there is no mechanism (currently) for
                // this function to return an error.
            }
            else if ( c == '&' )
            {
                to ~= entity[0].str;
            }
            else if ( c == '<' )
            {
                to ~= entity[1].str;
            }
            else if ( c == '>' )
            {
                to ~= entity[2].str;
            }
            else if ( c == '\"' )
            {
                to ~= entity[3].str;
            }
            else if ( c == '\'' )
            {
                to ~= entity[4].str;
            }
            else if ( c < 32 )
            {
                char[5] symbol = "&#x00";
                symbol[4] = std.string.hexdigits[(c & 0xff) >> 4];
                symbol[5] = std.string.hexdigits[c & 0xf];

                to ~= symbol;
            }
            else
            {
                to ~= c;
            }
        }
    }

    // Return true if the next characters in the stream are any of the endTag sequences.
    // Ignore case only works for english, and should only be relied on when comparing
    // to English words: StringEqual( p, "version", true ) is fine.
    static bool StringEqual(char[] p, char[] endTag, bool ignoreCase, TiXmlEncoding encoding )
    in
    {
        assert(p !is null && endTag !is null && p.length > 0 && endTag.length > 0);
    }
    body
    {           
        if ( ignoreCase )
        {
            return 0 == std.string.icmp(p[0 .. endTag.length], endTag);         
        }
        else
        {
            return 0 == std.string.cmp(p[0 .. endTag.length], endTag);          
        }       
    }

    static char[] errorString[ TIXML_ERROR_STRING_COUNT ];
        
    // None of these methods are reliable for any language except English.
    // Good for approximation, not great for accuracy.
    static int IsAlpha( char anyByte, TiXmlEncoding encoding )
    {
        // This will only work for low-ascii, everything else is assumed to be a valid
        // letter. I'm not sure this is the best approach, but it is quite tricky trying
        // to figure out alhabetical vs. not across encoding. So take a very 
        // conservative approach.
    
    //  if ( encoding == TIXML_ENCODING_UTF8 )
    //  {
            if ( anyByte < 127 )
                return isalpha( anyByte );
            else
                return 1;   // What else to do? The unicode set is huge...get the english ones right.
    //  }
    //  else
    //  {
    //      return isalpha( anyByte );
    //  }
    }

    static int IsAlphaNum( byte anyByte, TiXmlEncoding encoding )
    {
        // This will only work for low-ascii, everything else is assumed to be a valid
        // letter. I'm not sure this is the best approach, but it is quite tricky trying
        // to figure out alhabetical vs. not across encoding. So take a very 
        // conservative approach.
    
    //  if ( encoding == TIXML_ENCODING_UTF8 )
    //  {
            if ( anyByte < 127 )
                return isalnum( anyByte );
            else
                return 1;   // What else to do? The unicode set is huge...get the english ones right.
    //  }
    //  else
    //  {
    //      return isalnum( anyByte );
    //  }
    }
    /+
    static int ToLower( int v, TiXmlEncoding    encoding )
    {
        if ( encoding == TIXML_ENCODING_UTF8 )
        {
            if ( v < 128 ) return tolower( v );
            return v;
        }
        else
        {
            return tolower( v );
        }
    }
    +/
}


/** The parent class for everything in the Document Object Model.
    (Except for attributes).
    Nodes have siblings, a parent, and children. A node can be
    in a document, or stand on its own. The type of a TiXmlNode
    can be queried, and it can be cast to its more defined type.
*/
class TiXmlNode : public TiXmlBase
{
public: 
    /** The types of XML nodes supported by TinyXml. (All the
        unsupported types are picked up by UNKNOWN.)
    */
    enum NodeType
    {
        DOCUMENT,
        ELEMENT,
        COMMENT,
        UNKNOWN,
        TEXT,
        DECLARATION,
        TYPECOUNT
    }

    ~this()
    {
        TiXmlNode* node = firstChild;
        TiXmlNode* temp = 0;
    
        while ( node )
        {
            temp = node;
            node = node.next;
            delete temp;
        }   
    }

    /** The meaning of 'value' changes for the specific type of
        TiXmlNode.
        @verbatim
        Document:   filename of the xml file
        Element:    name of the element
        Comment:    the comment text
        Unknown:    the tag contents
        Text:       the text string
        @endverbatim

        The subclasses will wrap this function.
    */
    TiString Value() { return value; }

    /** Changes the value of the node. Defined as:
        @verbatim
        Document:   filename of the xml file
        Element:    name of the element
        Comment:    the comment text
        Unknown:    the tag contents
        Text:       the text string
        @endverbatim
    */
    void Value(TiString  _value) { value = _value;}

    /// Delete all the children of this node. Does not affect 'this'.
    void Clear()
    {
        TiXmlNode node = firstChild;
        TiXmlNode temp = 0;
    
        while ( node )
        {
            temp = node;
            node = node.next;
            delete temp;
        }   
    
        firstChild = 0;
        lastChild = 0;
    }

    /// One step up the DOM.
    TiXmlNode Parent()     { return parent; }
    
    TiXmlNode FirstChild() { return firstChild; }
    ///< The first child of this node with the matching 'value'. Will be null if none found.    
    TiXmlNode FirstChild( TiString v )
    {
        TiXmlNode node;
        for ( node = firstChild; node !is null; node = node.next )
        {
            if ( node.value == v)
                return node;
        }
        return null;
    }


    /// The last child of this node. Will be null if there are no children.
    TiXmlNode LastChild()  { return lastChild; }
    
    /// The last child of this node matching 'value'. Will be null if there are no children.
    TiXmlNode LastChild( string  v )
    {
        TiXmlNode* node;
        for ( node = firstChild; node !is null; node = node.prev )
        {
            if ( node.value == v)
                return node;
        }

        return null;
    }

    /** An alternate way to walk the children of a node.
        One way to iterate over nodes is:
        @verbatim
            for( child = parent.FirstChild(); child; child = child.NextSibling() )
        @endverbatim

        IterateChildren does the same thing with the syntax:
        @verbatim
            child = 0;
            while( child = parent.IterateChildren( child ) )
        @endverbatim

        IterateChildren takes the previous child as input and finds
        the next one. If the previous child is null, it returns the
        first. IterateChildren will return null when done.
    */
    TiXmlNode IterateChildren( TiXmlNode previous )
    {
        if ( previous is null )
        {
            return FirstChild();
        }
        else
        {
            assert( previous.parent == this );
            return previous.NextSibling();
        }
    }

    /// This flavor of IterateChildren searches for children with a particular 'value'
    TiXmlNode IterateChildren( string  value,  TiXmlNode previous )
    {
        if ( previous is null )
        {
            return FirstChild( val );
        }
        else
        {
            assert( previous.parent == this );
            return previous.NextSibling( val );
        }
    }


    /** Add a new node related to this. Adds a child past the LastChild.

        NOTE: the node to be added is passed by pointer, and will be
        henceforth owned (and deleted) by tinyXml. This method is efficient
        and avoids an extra copy, but should be used with care as it
        uses a different memory model than the other insert functions.

        @sa InsertEndChild
    */
    TiXmlNode LinkEndChild( TiXmlNode node )
    in
    {
        assert(node !is null);
    }
    body
    {
        node.parent = this;
    
        node.prev = lastChild;
        node.next = null;
    
        if ( lastChild !is null)
            lastChild.next = node;
        else
            firstChild = node;          // it was an empty list.
    
        lastChild = node;
        return node;
    }


    /** Add a new node related to this. Adds a child before the specified child.
        Returns a pointer to the new object or NULL if an error occured.
    */
    TiXmlNode InsertBeforeChild( TiXmlNode beforeThis, TiXmlNode node )
    {   
        if ( beforeThis is null || beforeThis.parent !is this )
            return null;
      
        node.parent = this;
    
        node.next = beforeThis;
        node.prev = beforeThis.prev;
        if ( beforeThis.prev !is null)
        {
            beforeThis.prev.next = node;
        }
        else
        {
            assert( firstChild == beforeThis );
            firstChild = node;
        }
        beforeThis.prev = node;
        return node;
    }

    /** Add a new node related to this. Adds a child after the specified child.
        Returns a pointer to the new object or NULL if an error occured.
    */
    TiXmlNode InsertAfterChild(  TiXmlNode afterThis, TiXmlNode node)
    {
        if ( afterThis is null || afterThis.parent !is this )
            return null;
    
        node.parent = this;
    
        node.prev = afterThis;
        node.next = afterThis.next;
        if ( afterThis.next !is null)
        {
            afterThis.next.prev = node;
        }
        else
        {
            assert( lastChild == afterThis );
            lastChild = node;
        }
        afterThis.next = node;
        return node;
    }
       

    /** Replace a child of this node.
        Returns a pointer to the new object or NULL if an error occured.
    */
    TiXmlNode ReplaceChild( TiXmlNode replaceThis, TiXmlNode node )
    {
        if ( replaceThis.parent !is this )
            return null;
       
        node.next = replaceThis.next;
        node.prev = replaceThis.prev;
    
        if ( replaceThis.next !is null)
            replaceThis.next.prev = node;
        else
            lastChild = node;
    
        if ( replaceThis.prev !is null)
            replaceThis.prev.next = node;
        else
            firstChild = node;
    
        delete replaceThis;
        node.parent = this;
        return node;
    }

    /// Delete a child of this node.
    bool RemoveChild( TiXmlNode removeThis )
    {
        if ( removeThis.parent !is this )
        {   
            assert( 0 );
            return false;
        }
    
        if ( removeThis.next !is null )
            removeThis.next.prev = removeThis.prev;
        else
            lastChild = removeThis.prev;
    
        if ( removeThis.prev !is null)
            removeThis.prev.next = removeThis.next;
        else
            firstChild = removeThis.next;
    
        delete removeThis;
        return true;
    }

    /// Navigate to a sibling node. 
    TiXmlNode PreviousSibling()                        { return prev; }

    /// Navigate to a sibling node. 
    TiXmlNode PreviousSibling( string  _value)
    {
        TiXmlNode node;
        for ( node = prev; node !is null; node = node.prev )
        {
            if ( node.value == _value)
                return node;
        }
        return null;
    }

    /// Navigate to a sibling node. 
    TiXmlNode NextSibling()                            { return next; }

    /// Navigate to a sibling node with the given 'value'.  
    TiXmlNode NextSibling( string  _value)
    {
        TiXmlNode* node;
        for ( node = next; node !is null; node = node.next )
        {
            if ( node.value == _value)
                return node;
        }
        return null;
    }

    /** Convenience function to get through elements.
        Calls NextSibling and ToElement. Will skip all non-Element
        nodes. Returns 0 if there is not another element.
    */
    TiXmlElement NextSiblingElement()
    {
        TiXmlNode node;
    
        for (node = NextSibling(); node !is null; node = node.NextSibling())
        {
            if ( node.ToElement() !is null)
                return node.ToElement();
        }
        return null;
    }

    /** Convenience function to get through elements.
        Calls NextSibling and ToElement. Will skip all non-Element
        nodes. Returns 0 if there is not another element.
    */  
    TiXmlElement NextSiblingElement( string _value )
    {
        TiXmlNode node;
    
        for (node = NextSibling( _value ); node !is null; node = node.NextSibling( _value ))
        {
            if ( node.ToElement() !is null)
                return node.ToElement();
        }
        return null;
    }

    /// Convenience function to get through elements.
    TiXmlElement FirstChildElement()
    {
        TiXmlNode node;
    
        for (node = FirstChild(); node !is null; node = node.NextSibling() )
        {
            if ( node.ToElement() !is null)
                return node.ToElement();
        }
        return null;
    }

    /// Convenience function to get through elements.
    TiXmlElement FirstChildElement( string _value )
    {
        TiXmlNode node;
    
        for (node = FirstChild(_value); node !is null; node = node.NextSibling(_value) )
        {
            if ( node.ToElement() !is null)
                return node.ToElement();
        }
        return null;
    }
    

    /** Query the type (as an enumerated value, above) of this node.
        The possible types are: DOCUMENT, ELEMENT, COMMENT,
                                UNKNOWN, TEXT, and DECLARATION.
    */
    int Type() { return type; }

    /** Return a pointer to the Document this node lives in.
        Returns null if not in a document.
    */
    TiXmlDocument GetDocument()
    {
        TiXmlNode node;
    
        for( node = this; node !is null; node = node.parent )
        {
            if ( node.ToDocument() !is null )
                return node.ToDocument();
        }
        return null;
    }

    /// Returns true if this node has no children.
    bool NoChildren()                      { return firstChild is null; }


    ///< Cast to a more defined type. Will return null not of the requested type.
    TiXmlDocument ToDocument() { return ( this && type == DOCUMENT ) ? cast(TiXmlDocument) this : null; }
    TiXmlElement  ToElement()  { return ( this && type == ELEMENT  ) ? cast(TiXmlElement)  this : null; }
    TiXmlComment  ToComment()  { return ( this && type == COMMENT  ) ? cast(TiXmlComment)  this : null; } 
    TiXmlUnknown  ToUnknown()  { return ( this && type == UNKNOWN  ) ? cast(TiXmlUnknown)  this : null; } 
    TiXmlText     ToText()     { return ( this && type == TEXT     ) ? cast(TiXmlText)     this : null; } 
    TiXmlDeclaration ToDeclaration()   { return ( this && type == DECLARATION ) ? cast(TiXmlDeclaration) this : null; } 

    /** Create an exact duplicate of this node and return it. The memory must be deleted
        by the caller. 
    */
    abstract TiXmlNode Clone();

protected:
    this( NodeType _type )
    {
        parent = null;
        type = _type;
        firstChild = null;
        lastChild = null;
        prev = null;
        next = null;
    }

    // Copy to the allocated object. Shared functionality between Clone, Copy constructor,
    // and the assignment operator.
    void CopyTo( TiXmlNode target )
    {
        target.Value(value);
        target.userData = userData; 
    }

    // Figure out what is at *p, and parse it. Returns null if it is not an xml node.
    TiXmlNode Identify(char[] p, TiXmlEncoding encoding )
    {
        TiXmlNode returnNode = null;
    
        p = SkipWhiteSpace( p, encoding );
        if( p is null || p.length == 0 || p[0] != '<' )
        {
            return null;
        }
    
        TiXmlDocument doc = GetDocument();        
    
        // What is this thing? 
        // - Elements start with a letter or underscore, but xml is reserved.
        // - Comments: <!--
        // - Decleration: <?xml
        // - Everthing else is unknown to tinyxml.
        //
    
        const char[] xmlHeader = "<?xml";
        const char[] commentHeader = "<!--";
        const char[] dtdHeader = "<!";
        const char[] cdataHeader = "<![CDATA[";
    
        if ( StringEqual( p, xmlHeader, true, encoding ) )
        {
            version(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Declaration\n" );

            returnNode = new TiXmlDeclaration();
        }
        else if ( StringEqual( p, commentHeader, false, encoding ) )
        {
            version(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Comment\n" );

            returnNode = new TiXmlComment();
        }
        else if ( StringEqual( p, cdataHeader, false, encoding ) )
        {
            version(DEBUG_PARSE)
                TIXML_LOG( "XML parsing CDATA\n" );

            TiXmlText text = new TiXmlText( "" );
            text.SetCDATA( true );
            returnNode = text;
        }
        else if ( StringEqual( p, dtdHeader, false, encoding ) )
        {
            version(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Unknown(DTD)\n" );

            returnNode = new TiXmlUnknown();
        }
        else if ( IsAlpha( p[1], encoding ) || p[1] == '_' )
        {
            version(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Element\n" );

            returnNode = new TiXmlElement( "" );
        }
        else
        {
            version(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Unknown(...)\n" );

            returnNode = new TiXmlUnknown();
        }
    
        if ( returnNode !is null)
        {
            // Set the parent, so it can report errors
            returnNode.parent = this;
        }
        else
        {
            if ( doc !is null )
                doc.SetError( TIXML_ERROR_OUT_OF_MEMORY, 0, 0, TIXML_ENCODING_UNKNOWN );
        }
        return returnNode;
    }

    TiXmlNode      parent;
    NodeType       type;

    TiXmlNode      firstChild, lastChild;

    TiString       value;

    TiXmlNode      prev, next;
}


/** An attribute is a name-value pair. Elements have an arbitrary
    number of attributes, each with a unique name.

    @note The attributes are not TiXmlNodes, since they are not
          part of the tinyXML document object model. There are other
          suggested ways to look at this problem.
*/
class TiXmlAttribute : public TiXmlBase
{
public:
    /// Construct an empty attribute.
    this()
    {
        super();
        document = null;
        prev = next = null;
    }

    /// Construct an attribute with a name and value.
    this( string _name, string  _value )
    {
        name = _name;
        value = _value;

        this();
    }

    char[] Name()  { return name; }       ///< Return the name of this attribute.
    char[] Value() { return value; }      ///< Return the value of this attribute.
    int IntValue()                        ///< Return the value of this attribute, converted to an integer.
    {
        return std.string.atoi(value);
    }
    double DoubleValue()                 ///< Return the value of this attribute, converted to a double.
    {
        return std.string.atof (value);
    }
    /+
    /** QueryIntValue examines the value string. It is an alternative to the
        IntValue() method with richer error checking.
        If the value is an integer, it is stored in 'value' and 
        the call returns TIXML_SUCCESS. If it is not
        an integer, it returns TIXML_WRONG_TYPE.

        A specialized but useful call. Note that for success it returns 0,
        which is the opposite of almost all other TinyXml calls.
    */
    int QueryIntValue( out int _value ) const
    {
        if ( sscanf( value.c_str(), "%d", ival ) == 1 )
            return TIXML_SUCCESS;
        return TIXML_WRONG_TYPE;
    }
    /// QueryDoubleValue examines the value string. See QueryIntValue().
    int QueryDoubleValue( double* _value ) const
    {
        if ( sscanf( value.c_str(), "%lf", dval ) == 1 )
            return TIXML_SUCCESS;
        return TIXML_WRONG_TYPE;
    }
    +/

    void Name( char[] _name )   { name = _name; }               ///< Set the name of this attribute.
    void Value( char[] _value ) { value = _value; }             ///< Set the value.

    void IntValue( int _value )                                 ///< Set the value from an integer.
    {
        value = std.string.toString(_value);
    }
    void DoubleValue( double _value )                       ///< Set the value from a double.
    {
        value = std.string.toString(_value);
    }

    
    /// Get the next sibling attribute in the DOM. Returns null at end.
    TiXmlAttribute Next()
    {
        // We are using knowledge of the sentinel. The sentinel
        // have a value or name.
        if ( next.value.length == 0 && next.name.length == 0 )
            return null;
        return next;
    }
    /// Get the previous sibling attribute in the DOM. Returns null at beginning.
    TiXmlAttribute Previous()
    {
        // We are using knowledge of the sentinel. The sentinel
        // have a value or name.
        if ( prev.value.length == 0 && prev.name.length == 0 )
            return null;
        return prev;
    }

    int opEqual(TiXmlAttribute rhs)
    {
        return rhs.name == name;
    }

    int opCmp(TiXmlAttribute rhs)
    {
        return std.string.cmp(name, rhs.name);
    }
    
    /*  Attribute parsing starts: first letter of the name
                         returns: the next char after the value end quote
    */
    char[] Parse( char[] p, TiXmlParsingData data, TiXmlEncoding encoding )
    {
        p = SkipWhiteSpace( p, encoding );
        if ( !p || !*p ) return null;
    
        int tabsize = 4;
        if ( document )
            tabsize = document.TabSize();
    
        if ( data )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
        // Read the name, the '=' and the value.
        char[] pErr = p;
        p = ReadName( p, &name, encoding );
        if ( !p || !*p )
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, pErr, data, encoding );
            return null;
        }
        p = SkipWhiteSpace( p, encoding );
        if ( !p || !*p || *p != '=' )
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
            return null;
        }
    
        ++p;    // skip '='
        p = SkipWhiteSpace( p, encoding );
        if ( !p || !*p )
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
            return null;
        }
        
        char[] end;
    
        if ( *p == '\'' )
        {
            ++p;
            end = "\'";
            p = ReadText( p, &value, false, end, false, encoding );
        }
        else if ( *p == '"' )
        {
            ++p;
            end = "\"";
            p = ReadText( p, &value, false, end, false, encoding );
        }
        else
        {
            // All attribute values should be in single or double quotes.
            // But this is such a common error that the parser will try
            // its best, even without them.
            value = "";
            while (    p && *p                                      // existence
                    && !IsWhiteSpace( *p ) && *p != '\n' && *p != '\r'  // whitespace
                    && *p != '/' && *p != '>' )                     // tag end
            {
                value += *p;
                ++p;
            }
        }
        return p;
    }

    // Prints this Attribute to a FILE stream.
    virtual void Print( FILE* cfile, int depth ) const
    {
        TIXML_STRING n, v;
    
        PutString( name, &n );
        PutString( value, &v );
    
        if (value.find ('\"') == TIXML_STRING::npos)
            fprintf (cfile, "%s=\"%s\"", n.c_str(), v.c_str() );
        else
            fprintf (cfile, "%s='%s'", n.c_str(), v.c_str() );
    }

    virtual void StreamOut( TIXML_OSTREAM * out ) const
    {
        if (value.find( '\"' ) != TIXML_STRING::npos)
        {
            PutString( name, stream );
            (*stream) << "=" << "'";
            PutString( value, stream );
            (*stream) << "'";
        }
        else
        {
            PutString( name, stream );
            (*stream) << "=" << "\"";
            PutString( value, stream );
            (*stream) << "\"";
        }
    }

    // [internal use]
    // Set the document pointer so the attribute can report errors.
    void SetDocument( TiXmlDocument* doc )  { document = doc; }

private:
    //TiXmlAttribute(   const TiXmlAttribute& );                // not implemented.
    //void operator=(   const TiXmlAttribute& base );   // not allowed.

    TiXmlDocument*  document;   // A pointer back to a document, for error reporting.
    TIXML_STRING name;
    TIXML_STRING value;
    TiXmlAttribute* prev;
    TiXmlAttribute* next;
}


/*  A class used to manage a group of attributes.
    It is only used internally, both by the ELEMENT and the DECLARATION.
    
    The set can be changed transparent to the Element and Declaration
    classes that use it, but NOT transparent to the Attribute
    which has to implement a next() and previous() method. Which makes
    it a bit problematic and prevents the use of STL.

    This version is implemented with circular lists because:
        - I like circular lists
        - it demonstrates some independence from the (typical) doubly linked list.
*/
class TiXmlAttributeSet
{
public:
    TiXmlAttributeSet()
    {
        sentinel.next = &sentinel;
        sentinel.prev = &sentinel;
    }
    ~TiXmlAttributeSet()
    {
        assert( sentinel.next == &sentinel );
        assert( sentinel.prev == &sentinel );
    }

    void Add( TiXmlAttribute* attribute )
    {
        assert( !Find( addMe.Name() ) );   // Shouldn't be multiply adding to the set.
    
        addMe.next = &sentinel;
        addMe.prev = sentinel.prev;
    
        sentinel.prev.next = addMe;
        sentinel.prev      = addMe;
    }
    void Remove( TiXmlAttribute* attribute )
    {
        TiXmlAttribute* node;
    
        for( node = sentinel.next; node != &sentinel; node = node.next )
        {
            if ( node == removeMe )
            {
                node.prev.next = node.next;
                node.next.prev = node.prev;
                node.next = 0;
                node.prev = 0;
                return;
            }
        }
        assert( 0 );        // we tried to remove a non-linked attribute.
    }


    TiXmlAttribute* First()                 { return ( sentinel.next == &sentinel ) ? 0 : sentinel.next; }

    TiXmlAttribute* Last()                  { return ( sentinel.prev == &sentinel ) ? 0 : sentinel.prev; }

    TiXmlAttribute* Find( string  name  )
    {
        TiXmlAttribute* node;
    
        for( node = sentinel.next; node != &sentinel; node = node.next )
        {
            if ( node.name == name )
                return node;
        }
        return null;
    }

private:
    //*ME:  Because of hidden/disabled copy-construktor in TiXmlAttribute (sentinel-element),
    //*ME:  this class must be also use a hidden/disabled copy-constructor !!!
    //TiXmlAttributeSet( const TiXmlAttributeSet& );    // not allowed
    //void operator=(   const TiXmlAttributeSet& ); // not allowed (as TiXmlAttribute)

    TiXmlAttribute sentinel;
}


/** The element is a container class. It has a value, the element name,
    and can contain other elements, text, comments, and unknowns.
    Elements also contain an arbitrary number of attributes.
*/
class TiXmlElement : public TiXmlNode
{
public:
    /// Construct an element.
    this (string  in_value) 
    {
        super( TiXmlNode::ELEMENT )
        firstChild = lastChild = 0;
        value = _value;
    }

    //TiXmlElement( const TiXmlElement& );

    //void operator=(   const TiXmlElement& base );

    ~this()
    {
        ClearThis();
    }

    /** Given an attribute name, Attribute() returns the value
        for the attribute of that name, or null if none exists.
    */
    char[] Attribute( char[] name ) const
    {
        const TiXmlAttribute* node = attributeSet.Find( name );
    
        if ( node )
            return node.Value();
    
        return null;
    }

    /** Given an attribute name, Attribute() returns the value
        for the attribute of that name, or null if none exists.
        If the attribute exists and can be converted to an integer,
        the integer value will be put in the return 'i', if 'i'
        is non-null.
    */
    char[] Attribute( char[] name, int* i ) const
    {
        const char * s = Attribute( name );
        if ( i )
        {
            if ( s )
                *i = atoi( s );
            else
                *i = 0;
        }
        return s;
    }

    /** Given an attribute name, Attribute() returns the value
        for the attribute of that name, or null if none exists.
        If the attribute exists and can be converted to an double,
        the double value will be put in the return 'd', if 'd'
        is non-null.
    */
    char[] Attribute( char[] name, double* d ) const
    {
        const char * s = Attribute( name );
        if ( d )
        {
            if ( s )
                *d = atof( s );
            else
                *d = 0;
        }
        return s;
    }


    /** QueryIntAttribute examines the attribute - it is an alternative to the
        Attribute() method with richer error checking.
        If the attribute is an integer, it is stored in 'value' and 
        the call returns TIXML_SUCCESS. If it is not
        an integer, it returns TIXML_WRONG_TYPE. If the attribute
        does not exist, then TIXML_NO_ATTRIBUTE is returned.
    */  
    int QueryIntAttribute( char[] name, int* _value ) const
    {
        const TiXmlAttribute* node = attributeSet.Find( name );
        if ( !node )
            return TIXML_NO_ATTRIBUTE;
    
        return node.QueryIntValue( ival );
    }
    
    /// QueryDoubleAttribute examines the attribute - see QueryIntAttribute().
    int QueryDoubleAttribute( char[] name, double* _value ) const
    {
        const TiXmlAttribute* node = attributeSet.Find( name );
        if ( !node )
            return TIXML_NO_ATTRIBUTE;
    
        return node.QueryDoubleValue( dval );
    }
    
    /// QueryFloatAttribute examines the attribute - see QueryIntAttribute().
    int QueryFloatAttribute( char[] name, float* _value ) const
    {
        double d;
        int result = QueryDoubleAttribute( name, &d );
        if ( result == TIXML_SUCCESS ) {
            *_value = (float)d;
        }
        return result;
    }

    /** Sets an attribute of name to a given value. The attribute
        will be created if it does not exist, or changed if it does.
    */
    void SetAttribute( char[] name, string  _value )
    {
        TiXmlAttribute* node = attributeSet.Find( name );
        if ( node )
        {
            node.SetValue( _value );
            return;
        }
    
        TiXmlAttribute* attrib = new TiXmlAttribute( name, _value );
        if ( attrib )
        {
            attributeSet.Add( attrib );
        }
        else
        {
            TiXmlDocument* document = GetDocument();
            if ( document ) document.SetError( TIXML_ERROR_OUT_OF_MEMORY, 0, 0, TIXML_ENCODING_UNKNOWN );
        }
    }
  
    /** Sets an attribute of name to a given value. The attribute
        will be created if it does not exist, or changed if it does.
    */
    void SetAttribute( string   name, int value )
    {   
        char buf[64];
        sprintf( buf, "%d", val );
        SetAttribute( name, buf );
    }

    /** Sets an attribute of name to a given value. The attribute
        will be created if it does not exist, or changed if it does.
    */
    void SetDoubleAttribute( string  name, double value )
    {   
        char buf[256];
        #if defined(TIXML_SNPRINTF)     
            TIXML_SNPRINTF( buf, sizeof(buf), "%f", val );
        #else
            sprintf( buf, "%f", val );
        #endif
        SetAttribute( name, buf );
    }

    /** Deletes an attribute with the given name.
    */
    void RemoveAttribute( string  name  )
    {
        TiXmlAttribute* node = attributeSet.Find( name );
        if ( node )
        {
            attributeSet.Remove( node );
            delete node;
        }
    }
    
    ///< Access the first attribute in this element.
    TiXmlAttribute* FirstAttribute()                { return attributeSet.First(); }
    ///< Access the last attribute in this element.
    TiXmlAttribute* LastAttribute()                 { return attributeSet.Last(); }

    /** Convenience function for easy access to the text inside an element. Although easy
        and concise, GetText() is limited compared to getting the TiXmlText child
        and accessing it directly.
    
        If the first child of 'this' is a TiXmlText, the GetText()
        returns the character string of the Text node, else null is returned.

        This is a convenient method for getting the text of simple contained text:
        @verbatim
        <foo>This is text</foo>
        char[] str = fooElement.GetText();
        @endverbatim

        'str' will be a pointer to "This is text". 
        
        Note that this function can be misleading. If the element foo was created from
        this XML:
        @verbatim
        <foo><b>This is text</b></foo> 
        @endverbatim

        then the value of str would be null. The first child node isn't a text node, it is
        another element. From this XML:
        @verbatim
        <foo>This is <b>text</b></foo> 
        @endverbatim
        GetText() will return "This is ".

        WARNING: GetText() accesses a child node - don't become confused with the 
                 similarly named TiXmlHandle::Text() and TiXmlNode::ToText() which are 
                 safe type casts on the referenced node.
    */
    char[] GetText() const
    {
        const TiXmlNode* child = this.FirstChild();
        if ( child ) {
            const TiXmlText* childText = child.ToText();
            if ( childText ) {
                return childText.Value();
            }
        }
        return null;
    }

    /// Creates a new Element and returns it - the returned element is a copy.
    TiXmlNode* Clone() const
    {
        TiXmlElement* clone = new TiXmlElement( Value() );
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    
    // Print the Element to a FILE stream.
    void Print( FILE* cfile, int depth ) const
    {
        int i;
        for ( i=0; i<depth; i++ )
        {
            fprintf( cfile, "    " );
        }
    
        fprintf( cfile, "<%s", value.c_str() );
    
        const TiXmlAttribute* attrib;
        for ( attrib = attributeSet.First(); attrib; attrib = attrib.Next() )
        {
            fprintf( cfile, " " );
            attrib.Print( cfile, depth );
        }
    
        // There are 3 different formatting approaches:
        // 1) An element without children is printed as a <foo /> node
        // 2) An element with only a text child is printed as <foo> text </foo>
        // 3) An element with children is printed on multiple lines.
        TiXmlNode* node;
        if ( !firstChild )
        {
            fprintf( cfile, " />" );
        }
        else if ( firstChild == lastChild && firstChild.ToText() )
        {
            fprintf( cfile, ">" );
            firstChild.Print( cfile, depth + 1 );
            fprintf( cfile, "</%s>", value.c_str() );
        }
        else
        {
            fprintf( cfile, ">" );
    
            for ( node = firstChild; node; node=node.NextSibling() )
            {
                if ( !node.ToText() )
                {
                    fprintf( cfile, "\n" );
                }
                node.Print( cfile, depth+1 );
            }
            fprintf( cfile, "\n" );
            for( i=0; i<depth; ++i )
            fprintf( cfile, "    " );
            fprintf( cfile, "</%s>", value.c_str() );
        }
    }

    /*  Attribtue parsing starts: next char past '<'
                         returns: next char past '>'
    */
    virtual char[] Parse( char[] p, TiXmlParsingData* data, TiXmlEncoding encoding )
    {
        p = SkipWhiteSpace( p, encoding );
        TiXmlDocument* document = GetDocument();
    
        if ( !p || !*p )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_ELEMENT, 0, 0, encoding );
            return null;
        }
    
        if ( data )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
    
        if ( *p != '<' )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_ELEMENT, p, data, encoding );
            return null;
        }
    
        p = SkipWhiteSpace( p+1, encoding );
    
        // Read the name.
        char[] pErr = p;
    
        p = ReadName( p, &value, encoding );
        if ( !p || !*p )
        {
            if ( document ) document.SetError( TIXML_ERROR_FAILED_TO_READ_ELEMENT_NAME, pErr, data, encoding );
            return null;
        }
    
        TIXML_STRING endTag ("</");
        endTag += value;
        endTag += ">";
    
        // Check for and read attributes. Also look for an empty
        // tag or an end tag.
        while ( p && *p )
        {
            pErr = p;
            p = SkipWhiteSpace( p, encoding );
            if ( !p || !*p )
            {
                if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, pErr, data, encoding );
                return null;
            }
            if ( *p == '/' )
            {
                ++p;
                // Empty tag.
                if ( *p  != '>' )
                {
                    if ( document ) document.SetError( TIXML_ERROR_PARSING_EMPTY, p, data, encoding );     
                    return null;
                }
                return (p+1);
            }
            else if ( *p == '>' )
            {
                // Done with attributes (if there were any.)
                // Read the value -- which can include other
                // elements -- read the end tag, and return.
                ++p;
                p = ReadValue( p, data, encoding );     // Note this is an Element method, and will set the error if one happens.
                if ( !p || !*p )
                    return null;
    
                // We should find the end tag now
                if ( StringEqual( p, endTag.c_str(), false, encoding ) )
                {
                    p += endTag.length();
                    return p;
                }
                else
                {
                    if ( document ) document.SetError( TIXML_ERROR_READING_END_TAG, p, data, encoding );
                    return null;
                }
            }
            else
            {
                // Try to read an attribute:
                TiXmlAttribute* attrib = new TiXmlAttribute();
                if ( !attrib )
                {
                    if ( document ) document.SetError( TIXML_ERROR_OUT_OF_MEMORY, pErr, data, encoding );
                    return null;
                }
    
                attrib.SetDocument( document );
                char[] pErr = p;
                p = attrib.Parse( p, data, encoding );
    
                if ( !p || !*p )
                {
                    if ( document ) document.SetError( TIXML_ERROR_PARSING_ELEMENT, pErr, data, encoding );
                    delete attrib;
                    return null;
                }
    
                // Handle the strange case of double attributes:
                TiXmlAttribute* node = attributeSet.Find( attrib.Name() );
                if ( node )
                {
                    node.SetValue( attrib.Value() );
                    delete attrib;
                    return null;
                }
    
                attributeSet.Add( attrib );
            }
        }
        return p;
    }

protected:

    void CopyTo( TiXmlElement* target ) const
    {
        // superclass:
        TiXmlNode::CopyTo( target );
    
        // Element class: 
        // Clone the attributes, then clone the children.
        const TiXmlAttribute* attribute = 0;
        for(    attribute = attributeSet.First();
        attribute;
        attribute = attribute.Next() )
        {
            target.SetAttribute( attribute.Name(), attribute.Value() );
        }
    
        TiXmlNode* node = 0;
        for ( node = firstChild; node; node = node.NextSibling() )
        {
            target.LinkEndChild( node.Clone() );
        }
    }
    void ClearThis()    // like clear, but initializes 'this' object as well
    {
        Clear();
        while( attributeSet.First() )
        {
            TiXmlAttribute* node = attributeSet.First();
            attributeSet.Remove( node );
            delete node;
        }
    }

    // Used to be public [internal use]
    virtual void StreamOut( TIXML_OSTREAM * out ) const
    {
        (*stream) << "<" << value;
    
        const TiXmlAttribute* attrib;
        for ( attrib = attributeSet.First(); attrib; attrib = attrib.Next() )
        {   
            (*stream) << " ";
            attrib.StreamOut( stream );
        }
    
        // If this node has children, give it a closing tag. Else
        // make it an empty tag.
        TiXmlNode* node;
        if ( firstChild )
        {       
            (*stream) << ">";
    
            for ( node = firstChild; node; node=node.NextSibling() )
            {
                node.StreamOut( stream );
            }
            (*stream) << "</" << value << ">";
        }
        else
        {
            (*stream) << " />";
        }
    }

    /*  [internal use]
        Reads the "value" of the element -- another element, or text.
        This should terminate with the current end tag.
    */
    char[] ReadValue( char[] in, TiXmlParsingData* prevData, TiXmlEncoding encoding )
    {
        TiXmlDocument* document = StreamOut();
    
        // Read in text and elements in any order.
        char[] pWithWhiteSpace = p;
        p = SkipWhiteSpace( p, encoding );
    
        while ( p && *p )
        {
            if ( *p != '<' )
            {
                // Take what we have, make a text element.
                TiXmlText* textNode = new TiXmlText( "" );
    
                if ( !textNode )
                {
                    if ( document ) document.SetError( TIXML_ERROR_OUT_OF_MEMORY, 0, 0, encoding );
                        return null;
                }
    
                if ( TiXmlBase::IsWhiteSpaceCondensed() )
                {
                    p = textNode.Parse( p, data, encoding );
                }
                else
                {
                    // Special case: we want to keep the white space
                    // so that leading spaces aren't removed.
                    p = textNode.Parse( pWithWhiteSpace, data, encoding );
                }
    
                if ( !textNode.Blank() )
                    LinkEndChild( textNode );
                else
                    delete textNode;
            } 
            else 
            {
                // We hit a '<'
                // Have we hit a new element or an end tag? This could also be
                // a TiXmlText in the "CDATA" style.
                if ( StringEqual( p, "</", false, encoding ) )
                {
                    return p;
                }
                else
                {
                    TiXmlNode* node = Identify( p, encoding );
                    if ( node )
                    {
                        p = node.Parse( p, data, encoding );
                        LinkEndChild( node );
                    }               
                    else
                    {
                        return null;
                    }
                }
            }
            pWithWhiteSpace = p;
            p = SkipWhiteSpace( p, encoding );
        }
    
        if ( !p )
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ELEMENT_VALUE, 0, 0, encoding );
        }   
        return p;
    }


private:

    TiXmlAttributeSet attributeSet;
}


/** An XML comment.
*/
class TiXmlComment : public TiXmlNode
{
public:
    /// Constructs an empty comment.
    this()
    {
       super( TiXmlNode::COMMENT );
    }

    /// Returns a copy of this Comment.
    TiXmlNode* Clone() const
    {
        TiXmlComment* clone = new TiXmlComment();
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    /// Write this Comment to a FILE stream.
    void Print( FILE* cfile, int depth ) const
    {
        for ( int i=0; i<depth; i++ )
        {
            fputs( "    ", cfile );
        }
        fprintf( cfile, "<!--%s-.", value.c_str() );
    }

    /*  Attribtue parsing starts: at the ! of the !--
                         returns: next char past '>'
    */
    char[] Parse( char[] p, TiXmlParsingData* data, TiXmlEncoding encoding )
    {
        TiXmlDocument* document = GetDocument();
        value = "";
    
        p = SkipWhiteSpace( p, encoding );
    
        if ( data )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
        char[] startTag = "<!--";
        char[] endTag   = "-.";
    
        if ( !StringEqual( p, startTag, false, encoding ) )
        {
            document.SetError( TIXML_ERROR_PARSING_COMMENT, p, data, encoding );
            return null;
        }
        p += strlen( startTag );
        p = ReadText( p, &value, false, endTag, false, encoding );
        return p;
    }

protected:
    void CopyTo( TiXmlComment* target ) const
    {
        TiXmlNode::CopyTo( target );
    }

    // used to be public    
    virtual void StreamOut( TIXML_OSTREAM * out ) const
    {
        (*stream) << "<!--";
        //PutString( value, stream );
        (*stream) << value;
        (*stream) << "-.";
    }

private:

}


/** XML text. A text node can have 2 ways to output the next. "normal" output 
    and CDATA. It will default to the mode it was parsed from the XML file and
    you generally want to leave it alone, but you can change the output mode with 
    SetCDATA() and query it with CDATA().
*/
class TiXmlText : public TiXmlNode
{
    friend class TiXmlElement;
public:
    /** Constructor for text element. By default, it is treated as 
        normal, encoded text. If you want it be output as a CDATA text
        element, set the parameter _cdata to 'true'
    */
    TiXmlText (string   initValue ) : TiXmlNode (TiXmlNode::TEXT)
    {
        SetValue( initValue );
        cdata = false;
    }   
    
    /// Write this text object to a FILE stream.
    void Print( FILE* cfile, int depth ) const
    {
        if ( cdata )
        {
            int i;
            fprintf( cfile, "\n" );
            for ( i=0; i<depth; i++ ) {
                fprintf( cfile, "    " );
            }
            fprintf( cfile, "<![CDATA[" );
            fprintf( cfile, "%s", value.c_str() );  // unformatted output
            fprintf( cfile, "]]>\n" );
        }
        else
        {
            TIXML_STRING buffer;
            PutString( value, &buffer );
            fprintf( cfile, "%s", buffer.c_str() );
        }
    }

    /// Queries whether this represents text using a CDATA section.
    bool CDATA()                    { return cdata; }
    /// Turns on or off a CDATA representation of text.
    void SetCDATA( bool _cdata )    { cdata = _cdata; }

    char[] Parse( char[] p, TiXmlParsingData* data, TiXmlEncoding encoding )
    {       
        value = "";
        TiXmlDocument* document = GetDocument();
    
        if ( data )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
    
        char[] const startTag = "<![CDATA[";
        char[] const endTag   = "]]>";
    
        if ( cdata || StringEqual( p, startTag, false, encoding ) )
        {
            cdata = true;
    
            if ( !StringEqual( p, startTag, false, encoding ) )
            {
                document.SetError( TIXML_ERROR_PARSING_CDATA, p, data, encoding );
                return null;
            }
            p += strlen( startTag );
    
            // Keep all the white space, ignore the encoding, etc.
            while (p && *p && !StringEqual( p, endTag, false, encoding )
                  )
            {
                value += *p;
                ++p;
            }
    
            TIXML_STRING dummy; 
            p = ReadText( p, &dummy, false, endTag, false, encoding );
            return p;
        }
        else
        {
            bool ignoreWhite = true;
    
            char[] end = "<";
            p = ReadText( p, &value, ignoreWhite, end, false, encoding );
            if ( p )
                return p-1; // don't truncate the '<'
            return null;
        }
    }


protected :
    ///  [internal use] Creates a new Element and returns it.
    virtual TiXmlNode* Clone() const
    {   
        TiXmlText* clone = 0;
        clone = new TiXmlText( "" );
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    void CopyTo( TiXmlText* target ) const
    {
        TiXmlNode::CopyTo( target );
        target.cdata = cdata;
    }


    virtual void StreamOut ( TIXML_OSTREAM * out ) const
    {
        if ( cdata )
        {
            (*stream) << "<![CDATA[" << value << "]]>";
        }
        else
        {
            PutString( value, stream );
        }
    }

    bool Blank() const  // returns true if all white space and new lines
    {
        for ( unsigned i=0; i<value.length(); i++ )
            if ( !IsWhiteSpace( value[i] ) )
                return false;
        return true;
    }
    // [internal use]
    
private:
    bool cdata;         // true if this should be input and output as a CDATA style text element
}


/** In correct XML the declaration is the first entry in the file.
    @verbatim
        <?xml version="1.0" standalone="yes"?>
    @endverbatim

    TinyXml will happily read or write files without a declaration,
    however. There are 3 possible attributes to the declaration:
    version, encoding, and standalone.

    Note: In this version of the code, the attributes are
    handled as special cases, not generic attributes, simply
    because there can only be at most 3 and they are always the same.
*/
class TiXmlDeclaration : public TiXmlNode
{
public:
    /// Construct an empty declaration.
    TiXmlDeclaration()
    {
       super( TiXmlNode::DECLARATION );
    }

    /// Construct.
    TiXmlDeclaration(   char[] _version,
                        char[] _encoding,
                        char[] _standalone )
    {
        this( TiXmlNode::DECLARATION )
 
        version = _version;
        encoding = _encoding;
        standalone = _standalone;
    }

    /// Version. Will return an empty string if none was found.
    string Version() const          { return version.c_str (); }
    /// Encoding. Will return an empty string if none was found.
    string Encoding() const     { return encoding.c_str (); }
    /// Is this a standalone document?
    string Standalone() const       { return standalone.c_str (); }

    /// Creates a copy of this Declaration and returns it.
    TiXmlNode* Clone() const
    {   
        TiXmlDeclaration* clone = new TiXmlDeclaration();
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    /// Print this declaration to a FILE stream.
    void Print( FILE* cfile, int depth ) const
    {
        fprintf (cfile, "<?xml ");
    
        if ( !version.empty() )
            fprintf (cfile, "version=\"%s\" ", version.c_str ());
        if ( !encoding.empty() )
            fprintf (cfile, "encoding=\"%s\" ", encoding.c_str ());
        if ( !standalone.empty() )
            fprintf (cfile, "standalone=\"%s\" ", standalone.c_str ());
        fprintf (cfile, "?>");
    }

    char[] Parse( char[] p, TiXmlParsingData* data, TiXmlEncoding encoding )
    {
        p = SkipWhiteSpace( p, _encoding );
        // Find the beginning, find the end, and look for
        // the stuff in-between.
        TiXmlDocument* document = GetDocument();
        if ( !p || !*p || !StringEqual( p, "<?xml", true, _encoding ) )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_DECLARATION, 0, 0, _encoding );
            return null;
        }
        if ( data )
        {
            data.Stamp( p, _encoding );
            location = data.Cursor();
        }
        p += 5;
    
        version = "";
        encoding = "";
        standalone = "";
    
        while ( p && *p )
        {
            if ( *p == '>' )
            {
                ++p;
                return p;
            }
    
            p = SkipWhiteSpace( p, _encoding );
            if ( StringEqual( p, "version", true, _encoding ) )
            {
                TiXmlAttribute attrib;
                p = attrib.Parse( p, data, _encoding );     
                version = attrib.Value();
            }
            else if ( StringEqual( p, "encoding", true, _encoding ) )
            {
                TiXmlAttribute attrib;
                p = attrib.Parse( p, data, _encoding );     
                encoding = attrib.Value();
            }
            else if ( StringEqual( p, "standalone", true, _encoding ) )
            {
                TiXmlAttribute attrib;
                p = attrib.Parse( p, data, _encoding );     
                standalone = attrib.Value();
            }
            else
            {
                // Read over whatever it is.
                while( p && *p && *p != '>' && !IsWhiteSpace( *p ) )
                    ++p;
            }
        }
        return null;
    }

protected:
    void CopyTo( TiXmlDeclaration* target ) const
    {
        TiXmlNode::CopyTo( target );
    
        target.version = version;
        target.encoding = encoding;
        target.standalone = standalone;
    }
    // used to be public
    
    virtual void StreamOut ( TIXML_OSTREAM * out) const
    {
        (*stream) << "<?xml ";
    
        if ( !version.empty() )
        {
            (*stream) << "version=\"";
            PutString( version, stream );
            (*stream) << "\" ";
        }
        if ( !encoding.empty() )
        {
            (*stream) << "encoding=\"";
            PutString( encoding, stream );
            (*stream ) << "\" ";
        }
        if ( !standalone.empty() )
        {
            (*stream) << "standalone=\"";
            PutString( standalone, stream );
            (*stream) << "\" ";
        }
        (*stream) << "?>";
    }

private:

    TIXML_STRING version;
    TIXML_STRING encoding;
    TIXML_STRING standalone;
}


/** Any tag that tinyXml doesn't recognize is saved as an
    unknown. It is a tag of text, but should not be modified.
    It will be written back to the XML, unchanged, when the file
    is saved.

    DTD tags get thrown into TiXmlUnknowns.
*/
class TiXmlUnknown : public TiXmlNode
{
public:
    TiXmlUnknown() : TiXmlNode( TiXmlNode::UNKNOWN )    {}

    /// Creates a copy of this Unknown and returns it.
    virtual TiXmlNode* Clone() const
    {
        TiXmlUnknown* clone = new TiXmlUnknown();
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    /// Print this Unknown to a FILE stream.
    virtual void Print( FILE* cfile, int depth ) const
    {
        for ( int i=0; i<depth; i++ )
            fprintf( cfile, "    " );
        fprintf( cfile, "<%s>", value.c_str() );
    }


    virtual char[] Parse( char[] p, TiXmlParsingData* data, TiXmlEncoding encoding )
    {
        TiXmlDocument* document = GetDocument();
        p = SkipWhiteSpace( p, encoding );
    
        if ( data )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
        if ( !p || !*p || *p != '<' )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_UNKNOWN, p, data, encoding );
            return null;
        }
        ++p;
        value = "";
    
        while ( p && *p && *p != '>' )
        {
            value += *p;
            ++p;
        }
    
        if ( !p )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_UNKNOWN, 0, 0, encoding );
        }
        if ( *p == '>' )
            return p+1;
        return p;
    }

protected:
    void CopyTo( TiXmlUnknown* target ) const
    {
        TiXmlNode::CopyTo( target );
    }

    void StreamOut ( TIXML_OSTREAM * out ) const
    {
        (*stream) << "<" << value << ">";       // Don't use entities here! It is unknown.
    }
}


/** Always the top level node. A document binds together all the
    XML pieces. It can be saved, loaded, and printed to the screen.
    The 'value' of a document node is the xml file name.
*/
class TiXmlDocument : public TiXmlNode
{
public:
    /// Create an empty document, that has no name.
    this()
    {
        this(null);
    }
    /// Create a document with a name. The name of the document is also the filename of the xml.
    this( string  documentName ): 
    {
        super( TiXmlNode::DOCUMENT )
        tabsize = 4;
        useMicrosoftBOM = false;
        value = documentName;
        ClearError();
    }

    /** Load a file using the current document value.
        Returns true if successful. Will delete any existing
        document data before loading.
    */
    bool LoadFile( TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
    {
        // See STL_STRING_BUG below.
        StringToBuffer buf( value );
    
        if ( buf.buffer && LoadFile( buf.buffer, encoding ) )
            return true;
    
        return false;
    }
    /// Save a file using the current document value. Returns true if successful.
    bool SaveFile() const
    {
        // See STL_STRING_BUG below.
        StringToBuffer buf( value );
    
        if ( buf.buffer && SaveFile( buf.buffer ) )
            return true;
    
        return false;
    }
    /// Load a file using the given filename. Returns true if successful.
    bool LoadFile( string  filename, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
    {
        // Delete the existing data:
        Clear();
        location.Clear();
    
        // There was a really terrifying little bug here. The code:
        //      value = filename
        // in the STL case, cause the assignment method of the std::string to
        // be called. What is strange, is that the std::string had the same
        // address as it's c_str() method, and so bad things happen. Looks
        // like a bug in the Microsoft STL implementation.
        // See STL_STRING_BUG above.
        // Fixed with the StringToBuffer class.
        value = filename;
    
        // reading in binary mode so that tinyxml can normalize the EOL
        FILE* file = fopen( value.c_str (), "rb" ); 
    
        if ( file )
        {
            // Get the file size, so we can pre-allocate the string. HUGE speed impact.
            long length = 0;
            fseek( file, 0, SEEK_END );
            length = ftell( file );
            fseek( file, 0, SEEK_SET );
    
            // Strange case, but good to handle up front.
            if ( length == 0 )
            {
                fclose( file );
                return false;
            }
    
            // If we have a file, assume it is all one big XML file, and read it in.
            // The document parser may decide the document ends sooner than the entire file, however.
            TIXML_STRING data;
            data.reserve( length );
    
            // Subtle bug here. TinyXml did use fgets. But from the XML spec:
            // 2.11 End-of-Line Handling
            // <snip>
            // <quote>
            // ...the XML processor MUST behave as if it normalized all line breaks in external 
            // parsed entities (including the document entity) on input, before parsing, by translating 
            // both the two-character sequence #xD #xA and any #xD that is not followed by #xA to 
            // a single #xA character.
            // </quote>
            //
            // It is not clear fgets does that, and certainly isn't clear it works cross platform. 
            // Generally, you expect fgets to translate from the convention of the OS to the c/unix
            // convention, and not work generally.
    
            /*
            while( fgets( buf, sizeof(buf), file ) )
            {
                data += buf;
            }
            */
    
            char* buf = new char[ length+1 ];
            buf[0] = 0;
    
            if ( fread( buf, length, 1, file ) != 1 ) {
            //if ( fread( buf, 1, length, file ) != (size_t)length ) {
                SetError( TIXML_ERROR_OPENING_FILE, 0, 0, TIXML_ENCODING_UNKNOWN );
                fclose( file );
                return false;
            }
            fclose( file );
    
            char[] lastPos = buf;
            char[] p = buf;
    
            buf[length] = 0;
            while( *p ) {
                assert( p < (buf+length) );
                if ( *p == 0xa ) {
                    // Newline character. No special rules for this. Append all the characters
                    // since the last string, and include the newline.
                    data.append( lastPos, p-lastPos+1 );    // append, include the newline
                    ++p;                                    // move past the newline
                    lastPos = p;                            // and point to the new buffer (may be 0)
                    assert( p <= (buf+length) );
                }
                else if ( *p == 0xd ) {
                    // Carriage return. Append what we have so far, then
                    // handle moving forward in the buffer.
                    if ( (p-lastPos) > 0 ) {
                        data.append( lastPos, p-lastPos );  // do not add the CR
                    }
                    data += (char)0xa;                      // a proper newline
    
                    if ( *(p+1) == 0xa ) {
                        // Carriage return - new line sequence
                        p += 2;
                        lastPos = p;
                        assert( p <= (buf+length) );
                    }
                    else {
                        // it was followed by something else...that is presumably characters again.
                        ++p;
                        lastPos = p;
                        assert( p <= (buf+length) );
                    }
                }
                else {
                    ++p;
                }
            }
            // Handle any left over characters.
            if ( p-lastPos ) {
                data.append( lastPos, p-lastPos );
            }       
            delete [] buf;
            buf = 0;
    
            Parse( data.c_str(), 0, encoding );
    
            if (  Error() )
                return false;
            else
                return true;
        }
        SetError( TIXML_ERROR_OPENING_FILE, 0, 0, TIXML_ENCODING_UNKNOWN );
        return false;
    }
    /// Save a file using the given filename. Returns true if successful.
    bool SaveFile( string  filename ) const
    {
        // The old c stuff lives on...
        FILE* fp = fopen( filename, "w" );
        if ( fp )
        {
            if ( useMicrosoftBOM ) 
            {
                const unsigned char TIXML_UTF_LEAD_0 = 0xefU;
                const unsigned char TIXML_UTF_LEAD_1 = 0xbbU;
                const unsigned char TIXML_UTF_LEAD_2 = 0xbfU;
    
                fputc( TIXML_UTF_LEAD_0, fp );
                fputc( TIXML_UTF_LEAD_1, fp );
                fputc( TIXML_UTF_LEAD_2, fp );
            }
            Print( fp, 0 );
            fclose( fp );
            return true;
        }
        return false;
    }

    /** Parse the given null terminated block of xml data. Passing in an encoding to this
        method (either TIXML_ENCODING_LEGACY or TIXML_ENCODING_UTF8 will force TinyXml
        to use that encoding, regardless of what TinyXml might otherwise try to detect.
    */
    virtual char[] Parse( char[] p, TiXmlParsingData* data = 0, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
    {
        ClearError();
    
        // Parse away, at the document level. Since a document
        // contains nothing but other tags, most of what happens
        // here is skipping white space.
        if ( !p || !*p )
        {
            SetError( TIXML_ERROR_DOCUMENT_EMPTY, 0, 0, TIXML_ENCODING_UNKNOWN );
            return null;
        }
    
        // Note that, for a document, this needs to come
        // before the while space skip, so that parsing
        // starts from the pointer we are given.
        location.Clear();
        if ( prevData )
        {
            location.row = prevData.cursor.row;
            location.col = prevData.cursor.col;
        }
        else
        {
            location.row = 0;
            location.col = 0;
        }
        TiXmlParsingData data( p, TabSize(), location.row, location.col );
        location = data.Cursor();
    
        if ( encoding == TIXML_ENCODING_UNKNOWN )
        {
            // Check for the Microsoft UTF-8 lead bytes.
            const unsigned char* pU = (const unsigned char*)p;
            if (    *(pU+0) && *(pU+0) == TIXML_UTF_LEAD_0
                 && *(pU+1) && *(pU+1) == TIXML_UTF_LEAD_1
                 && *(pU+2) && *(pU+2) == TIXML_UTF_LEAD_2 )
            {
                encoding = TIXML_ENCODING_UTF8;
                useMicrosoftBOM = true;
            }
        }
    
        p = SkipWhiteSpace( p, encoding );
        if ( !p )
        {
            SetError( TIXML_ERROR_DOCUMENT_EMPTY, 0, 0, TIXML_ENCODING_UNKNOWN );
            return null;
        }
    
        while ( p && *p )
        {
            TiXmlNode* node = Identify( p, encoding );
            if ( node )
            {
                p = node.Parse( p, &data, encoding );
                LinkEndChild( node );
            }
            else
            {
                break;
            }
    
            // Did we get encoding info?
            if (encoding == TIXML_ENCODING_UNKNOWN && node.ToDeclaration() )
            {
                TiXmlDeclaration* dec = node.ToDeclaration();
                char[] enc = dec.Encoding();
                assert( enc );
    
                if ( *enc == 0 )
                    encoding = TIXML_ENCODING_UTF8;
                else if ( StringEqual( enc, "UTF-8", true, TIXML_ENCODING_UNKNOWN ) )
                    encoding = TIXML_ENCODING_UTF8;
                else if ( StringEqual( enc, "UTF8", true, TIXML_ENCODING_UNKNOWN ) )
                    encoding = TIXML_ENCODING_UTF8; // incorrect, but be nice
                else 
                    encoding = TIXML_ENCODING_LEGACY;
            }
    
            p = SkipWhiteSpace( p, encoding );
        }
    
        // Was this empty?
        if ( !firstChild ) {
            SetError( TIXML_ERROR_DOCUMENT_EMPTY, 0, 0, encoding );
            return null;
        }
    
        // All is well.
        return p;
    }

    /** Get the root element -- the only top level element -- of the document.
        In well formed XML, there should only be one. TinyXml is tolerant of
        multiple elements at the document level.
    */
    const TiXmlElement* RootElement() const     { return FirstChildElement(); }
    TiXmlElement* RootElement()                 { return FirstChildElement(); }

    /** If an error occurs, Error will be set to true. Also,
        - The ErrorId() will contain the integer identifier of the error (not generally useful)
        - The ErrorDesc() method will return the name of the error. (very useful)
        - The ErrorRow() and ErrorCol() will return the location of the error (if known)
    */  
    bool Error() const                      { return error; }

    /// Contains a textual (english) description of the error if one occurs.
    string  ErrorDesc() const   { return errorDesc.c_str (); }

    /** Generally, you probably want the error string ( ErrorDesc() ). But if you
        prefer the ErrorId, this function will fetch it.
    */
    int ErrorId()   const               { return errorId; }

    /** Returns the location (if known) of the error. The first column is column 1, 
        and the first row is row 1. A value of 0 means the row and column wasn't applicable
        (memory errors, for example, have no row/column) or the parser lost the error. (An
        error in the error reporting, in that case.)

        @sa SetTabSize, Row, Column
    */
    int ErrorRow()  { return errorLocation.row+1; }
    int ErrorCol()  { return errorLocation.col+1; } ///< The column where the error occured. See ErrorRow()

    /** SetTabSize() allows the error reporting functions (ErrorRow() and ErrorCol())
        to report the correct values for row and column. It does not change the output
        or input in any way.
        
        By calling this method, with a tab size
        greater than 0, the row and column of each node and attribute is stored
        when the file is loaded. Very useful for tracking the DOM back in to
        the source file.

        The tab size is required for calculating the location of nodes. If not
        set, the default of 4 is used. The tabsize is set per document. Setting
        the tabsize to 0 disables row/column tracking.

        Note that row and column tracking is not supported when using operator>>.

        The tab size needs to be enabled before the parse or load. Correct usage:
        @verbatim
        TiXmlDocument doc;
        doc.SetTabSize( 8 );
        doc.Load( "myfile.xml" );
        @endverbatim

        @sa Row, Column
    */
    void SetTabSize( int _tabsize )     { tabsize = _tabsize; }

    int TabSize() const { return tabsize; }

    /** If you have handled the error, it can be reset with this call. The error
        state is automatically cleared if you Parse a new XML block.
    */
    void ClearError()
    {
        error = false; 
        errorId = 0; 
        errorDesc = ""; 
        errorLocation.row = errorLocation.col = 0; 
        //errorLocation.last = 0; 
    }

    /** Dump the document to standard out. */
    void Print() const                      { Print( stdout, 0 ); }

    /// Print this Document to a FILE stream.
    virtual void Print( FILE* cfile, int depth = 0 ) const
    {
        const TiXmlNode* node;
        for ( node=FirstChild(); node; node=node.NextSibling() )
        {
            node.Print( cfile, depth );
            fprintf( cfile, "\n" );
        }
    }

    // [internal use]
    void SetError( int err, char[] errorLocation, TiXmlParsingData* prevData, TiXmlEncoding encoding )
    {   
        // The first error in a chain is more accurate - don't set again!
        if ( error )
            return;
    
        assert( err > 0 && err < TIXML_ERROR_STRING_COUNT );
        error   = true;
        errorId = err;
        errorDesc = errorString[ errorId ];
    
        errorLocation.Clear();
        if ( pError && data )
        {
            data.Stamp( pError, encoding );
            errorLocation = data.Cursor();
        }
    }

protected :
    virtual void StreamOut ( TIXML_OSTREAM * out) const
    {
        const TiXmlNode* node;
        for ( node=FirstChild(); node; node=node.NextSibling() )
        {
            node.StreamOut( out );
    
            // Special rule for streams: stop after the root element.
            // The stream in code will only read one element, so don't
            // write more than one.
            if ( node.ToElement() )
                break;
        }
    }
    // [internal use]
    virtual TiXmlNode* Clone() const
    {
        TiXmlDocument* clone = new TiXmlDocument();
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    
private:
    void CopyTo( TiXmlDocument* target ) const
    {
        TiXmlNode::CopyTo( target );
    
        target.error = error;
        target.errorDesc = errorDesc.c_str ();
    
        TiXmlNode* node = 0;
        for ( node = firstChild; node; node = node.NextSibling() )
        {
            target.LinkEndChild( node.Clone() );
        }   
    }

    bool error;
    int  errorId;
    TIXML_STRING errorDesc;
    int tabsize;
    TiXmlCursor errorLocation;
    bool useMicrosoftBOM;       // the UTF-8 BOM were found when read. Note this, and try to write.
}


/**
    A TiXmlHandle is a class that wraps a node pointer with null checks; this is
    an incredibly useful thing. Note that TiXmlHandle is not part of the TinyXml
    DOM structure. It is a separate utility class.

    Take an example:
    @verbatim
    <Document>
        <Element attributeA = "valueA">
            <Child attributeB = "value1" />
            <Child attributeB = "value2" />
        </Element>
    <Document>
    @endverbatim

    Assuming you want the value of "attributeB" in the 2nd "Child" element, it's very 
    easy to write a *lot* of code that looks like:

    @verbatim
    TiXmlElement* root = document.FirstChildElement( "Document" );
    if ( root )
    {
        TiXmlElement* element = root.FirstChildElement( "Element" );
        if ( element )
        {
            TiXmlElement* child = element.FirstChildElement( "Child" );
            if ( child )
            {
                TiXmlElement* child2 = child.NextSiblingElement( "Child" );
                if ( child2 )
                {
                    // Finally do something useful.
    @endverbatim

    And that doesn't even cover "else" cases. TiXmlHandle addresses the verbosity
    of such code. A TiXmlHandle checks for null pointers so it is perfectly safe 
    and correct to use:

    @verbatim
    TiXmlHandle docHandle( &document );
    TiXmlElement* child2 = docHandle.FirstChild( "Document" ).FirstChild( "Element" ).Child( "Child", 1 ).Element();
    if ( child2 )
    {
        // do something useful
    @endverbatim

    Which is MUCH more concise and useful.

    It is also safe to copy handles - internally they are nothing more than node pointers.
    @verbatim
    TiXmlHandle handleCopy = handle;
    @endverbatim

    What they should not be used for is iteration:

    @verbatim
    int i=0; 
    while ( true )
    {
        TiXmlElement* child = docHandle.FirstChild( "Document" ).FirstChild( "Element" ).Child( "Child", i ).Element();
        if ( !child )
            break;
        // do something
        ++i;
    }
    @endverbatim

    It seems reasonable, but it is in fact two embedded while loops. The Child method is 
    a linear walk to find the element, so this code would iterate much more than it needs 
    to. Instead, prefer:

    @verbatim
    TiXmlElement* child = docHandle.FirstChild( "Document" ).FirstChild( "Element" ).FirstChild( "Child" ).Element();

    for( child; child; child=child.NextSiblingElement() )
    {
        // do something
    }
    @endverbatim
*/
class TiXmlHandle
{
public:
    /// Create a handle from any node (at any depth of the tree.) This can be a null pointer.
    TiXmlHandle( TiXmlNode* _node )                 { this.node = _node; }
    /// Copy constructor
    TiXmlHandle( const TiXmlHandle& ref )           { this.node = ref.node; }
    TiXmlHandle operator=( const TiXmlHandle& ref ) { this.node = ref.node; return *this; }

    /// Return a handle to the first child node.
    TiXmlHandle FirstChild() const
    {
        if ( node )
        {
            TiXmlNode* child = node.FirstChild();
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }
    /// Return a handle to the first child node with the given name.
    TiXmlHandle FirstChild( string  value ) const
    {
        if ( node )
        {
            TiXmlNode* child = node.FirstChild( value );
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }
    /// Return a handle to the first child element.
    TiXmlHandle FirstChildElement() const
    {
        if ( node )
        {
            TiXmlElement* child = node.FirstChildElement();
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }

    /// Return a handle to the first child element with the given name.
    TiXmlHandle FirstChildElement( string  value ) const
    {
        if ( node )
        {
            TiXmlElement* child = node.FirstChildElement( value );
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }

    /** Return a handle to the "index" child with the given name. 
        The first child is 0, the second 1, etc.
    */
    TiXmlHandle Child( char[] value, int index ) const
    {
        if ( node )
        {
            int i;
            TiXmlNode* child = node.FirstChild( value );
            for (   i=0;
                    child && i<count;
                    child = child.NextSibling( value ), ++i )
            {
                // nothing
            }
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }

    /** Return a handle to the "index" child. 
        The first child is 0, the second 1, etc.
    */
    TiXmlHandle Child( int index ) const
    {
        if ( node )
        {
            int i;
            TiXmlNode* child = node.FirstChild();
            for (   i=0;
                    child && i<count;
                    child = child.NextSibling(), ++i )
            {
                // nothing
            }
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }
    /** Return a handle to the "index" child element with the given name. 
        The first child element is 0, the second 1, etc. Note that only TiXmlElements
        are indexed: other types are not counted.
    */
    TiXmlHandle ChildElement( char[] value, int index ) const
    {
        if ( node )
        {
            int i;
            TiXmlElement* child = node.FirstChildElement( value );
            for (   i=0;
                    child && i<count;
                    child = child.NextSiblingElement( value ), ++i )
            {
                // nothing
            }
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }
    /** Return a handle to the "index" child element. 
        The first child element is 0, the second 1, etc. Note that only TiXmlElements
        are indexed: other types are not counted.
    */
    TiXmlHandle ChildElement( int index ) const
    {
        if ( node )
        {
            int i;
            TiXmlElement* child = node.FirstChildElement();
            for (   i=0;
                    child && i<count;
                    child = child.NextSiblingElement(), ++i )
            {
                // nothing
            }
            if ( child )
                return TiXmlHandle( child );
        }
        return TiXmlHandle( 0 );
    }


    /// Return the handle as a TiXmlNode. This may return null.
    TiXmlNode* Node() const         { return node; } 
    /// Return the handle as a TiXmlElement. This may return null.
    TiXmlElement* Element() const   { return ( ( node && node.ToElement() ) ? node.ToElement() : 0 ); }
    /// Return the handle as a TiXmlText. This may return null.
    TiXmlText* Text() const         { return ( ( node && node.ToText() ) ? node.ToText() : 0 ); }
    /// Return the handle as a TiXmlUnknown. This may return null;
    TiXmlUnknown* Unknown() const           { return ( ( node && node.ToUnknown() ) ? node.ToUnknown() : 0 ); }

private:
    TiXmlNode* node;
}


class TiXmlParsingData
{   
public:
    void Stamp( char[] now, TiXmlEncoding encoding )
    {
        assert( now );
    
        // Do nothing if the tabsize is 0.
        if ( tabsize < 1 )
        {
            return;
        }
    
        // Get the current row, column.
        int row = cursor.row;
        int col = cursor.col;
        char[] p = stamp;
        assert( p );
    
        while ( p < now )
        {
            // Treat p as unsigned, so we have a happy compiler.
            const unsigned char* pU = (const unsigned char*)p;
    
            // Code contributed by Fletcher Dunn: (modified by lee)
            switch (*pU) {
                case 0:
                    // We *should* never get here, but in case we do, don't
                    // advance past the terminating null character, ever
                    return;
    
                case '\r':
                    // bump down to the next line
                    ++row;
                    col = 0;                
                    // Eat the character
                    ++p;
    
                    // Check for \r\n sequence, and treat this as a single character
                    if (*p == '\n') {
                        ++p;
                    }
                    break;
    
                case '\n':
                    // bump down to the next line
                    ++row;
                    col = 0;
    
                    // Eat the character
                    ++p;
    
                    // Check for \n\r sequence, and treat this as a single
                    // character.  (Yes, this bizarre thing does occur still
                    // on some arcane platforms...)
                    if (*p == '\r') {
                        ++p;
                    }
                    break;
    
                case '\t':
                    // Eat the character
                    ++p;
    
                    // Skip to next tab stop
                    col = (col / tabsize + 1) * tabsize;
                    break;
    
                case TIXML_UTF_LEAD_0:
                    if ( encoding == TIXML_ENCODING_UTF8 )
                    {
                        if ( *(p+1) && *(p+2) )
                        {
                            // In these cases, don't advance the column. These are
                            // 0-width spaces.
                            if ( *(pU+1)==TIXML_UTF_LEAD_1 && *(pU+2)==TIXML_UTF_LEAD_2 )
                                p += 3; 
                            else if ( *(pU+1)==0xbfU && *(pU+2)==0xbeU )
                                p += 3; 
                            else if ( *(pU+1)==0xbfU && *(pU+2)==0xbfU )
                                p += 3; 
                            else
                                { p +=3; ++col; }   // A normal character.
                        }
                    }
                    else
                    {
                        ++p;
                        ++col;
                    }
                    break;
    
                default:
                    if ( encoding == TIXML_ENCODING_UTF8 )
                    {
                        // Eat the 1 to 4 byte utf8 character.
                        int step = TiXmlBase::utf8ByteTable[*((unsigned char*)p)];
                        if ( step == 0 )
                            step = 1;       // Error case from bad encoding, but handle gracefully.
                        p += step;
    
                        // Just advance one column, of course.
                        ++col;
                    }
                    else
                    {
                        ++p;
                        ++col;
                    }
                    break;
            }
        }
        cursor.row = row;
        cursor.col = col;
        assert( cursor.row >= -1 );
        assert( cursor.col >= -1 );
        stamp = p;
        assert( stamp );
    }

    const TiXmlCursor& Cursor() { return cursor; }

  private:
    // Only used by the document!
    TiXmlParsingData( char[] start, int _tabsize, int row, int col )
    {
        assert( start );
        stamp = start;
        tabsize = _tabsize;
        cursor.row = row;
        cursor.col = col;
    }

    TiXmlCursor     cursor;
    char[] stamp;
    int             tabsize;
}
