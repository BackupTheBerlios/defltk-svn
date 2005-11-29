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

import std.string, std.file, std.utf, std.stdio;

// debug = TI_DEBUG
debug(DEBUG_PARSE)
    alias std.stdio.writefln TIXML_LOG;

/+
#if defined( DEBUG ) && defined( _MSC_VER )
#include <windows.h>
#define TIXML_LOG OutputDebugString
#else
#define TIXML_LOG printf
#endif
+/
alias char[]        string;

//class TiXmlDocument;
//class TiXmlElement;
//class TiXmlComment;
//class TiXmlUnknown;
//class TiXmlAttribute;
//class TiXmlText;
//class TiXmlDeclaration;
//class TiXmlParsingData;

const int TIXML_VERSION = 0x242;

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
    UNKNOWN,
    UTF8,
    LEGACY
}

const TiXmlEncoding TIXML_DEFAULT_ENCODING = TiXmlEncoding.UNKNOWN;

bool IsWhiteSpace(char c)
{
    return std.string.iswhite(c) == 0;
}

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
    abstract char[] toString( int depth );

    /** Return the position, in the original source file, of this node or attribute.
        The row and column are 1-based. (That is the first row and first column is
        1,1). If the returns values are 0 or less, then the parser does not have
        a row and column value.

        Generally, the row and column value will be set when the TiXmlDocument::Load(),
        TiXmlDocument::LoadFile(), or any TiXmlNode.Parse() is called. It will NOT be set
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

    abstract char[] Parse(char[] p, TiXmlParsingData data, TiXmlEncoding encoding /*= TiXmlEncoding.UNKNOWN */ );

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
    
    const Entity amp = { "&amp;",  5, '&' };
    const Entity lt = { "&lt;",   4, '<' };
    const Entity gt = { "&gt;",   4, '>' };
    const Entity quot = { "&quot;", 6, '\"' };
    const Entity apos = { "&apos;", 6, '\'' };
    
    static Entity entity[] = [ amp, lt, gt, quot, apos ];
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
        
        if ( encoding == TiXmlEncoding.UTF8 )
        {
            if(isUTF8LeadingBytes(p[0..3]))
            {
                p = p[3 .. $];
            }
        }

        foreach(int i, dchar c; p)
        {
            if(!std.string.isspace(c))
            {
                return p[i..$];
            }               
        }
    
        return null;
    }

    /*  Reads an XML name into the string provided. Returns
        a pointer just past the last character of the name,
        or 0 if the function has an error.
    */
    static char[] ReadName(char[] p, out char[] name, TiXmlEncoding encoding)
    in
    {
        assert( p !is null);
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
            foreach(int i, dchar c; p[0..$])
            {
                if(!(IsAlphaNum(c , encoding) 
                             || c == '_'
                             || c == '-'
                             || c == '.'
                             || c == ':'))
                {
                    name = p[0..i];                    
                    return p[i..$];
                }               
            }
            name = "";
            return null;
        }
        name = null;
        return null;
    }

    static int findTag(char[] p, char[] tag, bool ignoreCase)
    {
        if(ignoreCase)
            return std.string.ifind(p, tag);
        else
            return std.string.find(p, tag);

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
                char[] number = p[3..end];

                foreach(char c; number)
                {
                    int value = std.string.ifind(std.string.hexdigits, c);
                    if(value == -1) return null;
                    ucs += value;
                    ucs << 4; //ucs * 16;
                }
                p = p[end + 1..$]; //skip ';'
            }
            else
            {
                // Decimal.
                if ( p.length < 3 ) return null;

                int end = find(p, ';');
                if ( end == -1 )  return null;

                char[] number = p[2..end];
    
                foreach(char c; number)
                {
                    int value = std.string.ifind(std.string.digits, c);
                    if(value == -1) return null;
                    ucs += value;
                    ucs *= 10;
                }
                p = p[end + 1..$]; //skip ';'
            }

            if ( encoding == TiXmlEncoding.UTF8 )
            {
                // convert the UCS to UTF-8
                dchar[] a;
                a ~= ucs;
                value = std.utf.toUTF8(a);
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
        if ( encoding == TiXmlEncoding.UTF8 )
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
            _value = p[0..length];
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
            if (c == '&' && i < (from.length - 2) && from[i + 1] == '#' && from[i+2] == 'x')
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
                char[] symbol = "&#x00";
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
        debug(DEBUG_PARSE) writefln("%s == %s", p, endTag);
        if(p.length < endTag.length)
            return false;
    
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
    
    //  if ( encoding == TiXmlEncoding.UTF8 )
    //  {
            if ( anyByte < 127 )
                return std.string.isalpha(anyByte);
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
    
    //  if ( encoding == TiXmlEncoding.UTF8 )
    //  {
            if ( anyByte < 127 )
                return std.string.isalnum( anyByte );
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
        if ( encoding == TiXmlEncoding.UTF8 )
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
        TiXmlNode node = firstChild;
        TiXmlNode temp = null;
    
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
    char[] Value() { return value; }

    /** Changes the value of the node. Defined as:
        @verbatim
        Document:   filename of the xml file
        Element:    name of the element
        Comment:    the comment text
        Unknown:    the tag contents
        Text:       the text string
        @endverbatim
    */
    void Value(char[]  _value) { value = _value;}

    /// Delete all the children of this node. Does not affect 'this'.
    void Clear()
    {
        TiXmlNode node = firstChild;
        TiXmlNode temp = null;
    
        while ( node !is null )
        {
            temp = node;
            node = node.next;
            delete temp;
        }   
    
        firstChild = null;
        lastChild = null;
    }

    /// One step up the DOM.
    TiXmlNode Parent()     { return parent; }
    
    TiXmlNode FirstChild() { return firstChild; }
    ///< The first child of this node with the matching 'value'. Will be null if none found.    
    TiXmlNode FirstChild( char[] v )
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
    TiXmlNode LastChild( char[]  v )
    {
        TiXmlNode node;
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
    TiXmlNode IterateChildren( char[]  value,  TiXmlNode previous )
    {
        if ( previous is null )
        {
            return FirstChild( value );
        }
        else
        {
            assert( previous.parent == this );
            return previous.NextSibling( value );
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
        writefln("here is %s", lastChild !is null);
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
    TiXmlNode PreviousSibling( char[]  _value)
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
    TiXmlNode NextSibling( char[]  _value)
    {
        TiXmlNode node;
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
    TiXmlDocument ToDocument() { return ( type == NodeType.DOCUMENT ) ? cast(TiXmlDocument) this : null; }
    TiXmlElement  ToElement()  { return ( type == NodeType.ELEMENT  ) ? cast(TiXmlElement)  this : null; }
    TiXmlComment  ToComment()  { return ( type == NodeType.COMMENT  ) ? cast(TiXmlComment)  this : null; } 
    TiXmlUnknown  ToUnknown()  { return ( type == NodeType.UNKNOWN  ) ? cast(TiXmlUnknown)  this : null; } 
    TiXmlText     ToText()     { return ( type == NodeType.TEXT     ) ? cast(TiXmlText)     this : null; } 
    TiXmlDeclaration ToDeclaration(){ return ( type == NodeType.DECLARATION ) ? cast(TiXmlDeclaration) this : null; } 

    /** Create an exact duplicate of this node and return it. The memory must be deleted
        by the caller. 
    */
    //abstract TiXmlNode Clone();

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
    /+
    void CopyTo( TiXmlNode target )
    {
        target.Value(value);
        target.userData = userData; 
    }
    +/

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
            debug(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Declaration\n" );

            returnNode = new TiXmlDeclaration();
        }
        else if ( StringEqual( p, commentHeader, false, encoding ) )
        {
            debug(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Comment\n" );

            returnNode = new TiXmlComment();
        }
        else if ( StringEqual( p, cdataHeader, false, encoding ) )
        {
            debug(DEBUG_PARSE)
                TIXML_LOG( "XML parsing CDATA\n" );

            TiXmlText text = new TiXmlText( "" );
            text.SetCDATA( true );
            returnNode = text;
        }
        else if ( StringEqual( p, dtdHeader, false, encoding ) )
        {
            debug(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Unknown(DTD)\n" );

            returnNode = new TiXmlUnknown();
        }
        else if ( IsAlpha( p[1], encoding ) || p[1] == '_' )
        {
            debug(DEBUG_PARSE)
                TIXML_LOG( "XML parsing Element\n" );

            returnNode = new TiXmlElement( "" );
        }
        else
        {
            debug(DEBUG_PARSE)
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
                doc.SetError( TIXML_ERROR_OUT_OF_MEMORY, null, null, TiXmlEncoding.UNKNOWN );
        }
        return returnNode;
    }

    TiXmlNode      parent;
    NodeType       type;

    TiXmlNode      firstChild, lastChild;

    char[]       value;

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
    this( string _name, char[]  _value )
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
    int QueryIntValue( out int _value )
    {
        if ( sscanf( value.c_str(), "%d", ival ) == 1 )
            return TIXML_SUCCESS;
        return TIXML_WRONG_TYPE;
    }
    /// QueryDoubleValue examines the value string. See QueryIntValue().
    int QueryDoubleValue( double* _value )
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
        if ( p is null || p.length == 0 ) return null;
    
        int tabsize = 4;
        if ( document !is null)
            tabsize = document.TabSize();
    
        if ( data !is null )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
        // Read the name, the '=' and the value.
        char[] pErr = p;
        p = ReadName( p, name, encoding );
        if ( p is null)
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, pErr, data, encoding );
            return null;
        }
        p = SkipWhiteSpace( p, encoding );
        if ( p is null || p.length == 0 || p[0] != '=' )
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
            return null;
        }
    
        p = p[1 .. $];    // skip '='
        p = SkipWhiteSpace( p, encoding );
        if ( p is null || p.length == 0)
        {
            if ( document ) document.SetError( TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
            return null;
        }
        
        char[] end;
    
        if ( p[0] == '\'' )
        {
            end = "\'";
            p = ReadText( p[1 .. $], value, false, end, false, encoding );
        }
        else if ( *p == '"' )
        {
            end = "\"";
            p = ReadText( p[1 .. $], value, false, end, false, encoding );
        }
        else
        {
            // All attribute values should be in single or double quotes.
            // But this is such a common error that the parser will try
            // its best, even without them.
            value = "";
            const char[] saparator = std.string.whitespace ~ "/>";

            foreach(char c; p)
            {                
                if( -1 == std.string.find(saparator, c))
                {
                    value ~= c;
                }
            }
        }
        return p;
    }

    // Prints this Attribute to a FILE stream.
    char[] toString(int depth )
    {
        if (std.string.find (value, '\"') == -1)
            return name ~ "=\"" ~ value ~ "\"";
        else
            return name ~ "=\'" ~ value ~ "\'";
    }

    // [internal use]
    // Set the document pointer so the attribute can report errors.
    void Document( TiXmlDocument doc )  { document = doc; }

private:
    TiXmlDocument document;   // A pointer back to a document, for error reporting.
    char[] name;
    char[] value;
    TiXmlAttribute prev, next;
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
    this()
    {
        sentinel = null;
    }
    ~this()
    {
    }

    void Add( TiXmlAttribute addMe )
    {
        if(sentinel is null)
        {
            sentinel = addMe;
            sentinel.next = sentinel;
            sentinel.prev = sentinel;
        }

        assert( !Find( addMe.Name() ) );   // Shouldn't be multiply adding to the set.
    
        addMe.next = sentinel;
        addMe.prev = sentinel.prev;
    
        sentinel.prev.next = addMe;
        sentinel.prev      = addMe;
    }
    void Remove( TiXmlAttribute removeMe )
    {
        TiXmlAttribute node;
    
        for( node = sentinel.next; node !is sentinel; node = node.next )
        {
            if ( node is removeMe )
            {
                node.prev.next = node.next;
                node.next.prev = node.prev;
                node.next = null;
                node.prev = null;
                return;
            }
        }
    }


    TiXmlAttribute First() { return ( sentinel.next is sentinel ) ? null : sentinel.next; }

    TiXmlAttribute Last()  { return ( sentinel.prev is sentinel ) ? null : sentinel.prev; }

    TiXmlAttribute Find( char[]  name  )
    {
        TiXmlAttribute node;
    
        for( node = sentinel.next; node !is sentinel; node = node.next )
        {
            if ( node.name == name )
                return node;
        }
        return null;
    }

private:
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
    this (char[]  _value) 
    {
        super( TiXmlNode.NodeType.ELEMENT );
        firstChild = null;
        lastChild = null;
        value = _value;
        attributeSet = new TiXmlAttributeSet;
    }

    ~this()
    {
        ClearThis();
    }

    /** Given an attribute name, Attribute() returns the value
        for the attribute of that name, or null if none exists.
    */
    char[] Attribute( char[] name )
    {
        TiXmlAttribute node = attributeSet.Find( name );
    
        if ( node !is null )
            return node.Value();
    
        return null;
    }

    /** Given an attribute name, Attribute() returns the value
        for the attribute of that name, or null if none exists.
        If the attribute exists and can be converted to an integer,
        the integer value will be put in the return 'i', if 'i'
        is non-null.
    */
    char[] Attribute( char[] name, out int i )
    {
        TiXmlAttribute node = attributeSet.Find( name );
    
        if ( node !is null )
        {
            i = node.IntValue();
            return node.Value();
        }
        return null;
    }

    /** Given an attribute name, Attribute() returns the value
        for the attribute of that name, or null if none exists.
        If the attribute exists and can be converted to an double,
        the double value will be put in the return 'd', if 'd'
        is non-null.
    */
    char[] Attribute( char[] name, out double d )
    {
        TiXmlAttribute node = attributeSet.Find( name );
    
        if ( node !is null )
        {
            d = node.DoubleValue();
            return node.Value();
        }
        return null;
    }

    /+
    /** QueryIntAttribute examines the attribute - it is an alternative to the
        Attribute() method with richer error checking.
        If the attribute is an integer, it is stored in 'value' and 
        the call returns TIXML_SUCCESS. If it is not
        an integer, it returns TIXML_WRONG_TYPE. If the attribute
        does not exist, then TIXML_NO_ATTRIBUTE is returned.
    */  
    int QueryIntAttribute( char[] name, int* _value )
    {
        const TiXmlAttribute* node = attributeSet.Find( name );
        if ( !node )
            return TIXML_NO_ATTRIBUTE;
    
        return node.QueryIntValue( ival );
    }
    
    /// QueryDoubleAttribute examines the attribute - see QueryIntAttribute().
    int QueryDoubleAttribute( char[] name, double* _value )
    {
        const TiXmlAttribute* node = attributeSet.Find( name );
        if ( !node )
            return TIXML_NO_ATTRIBUTE;
    
        return node.QueryDoubleValue( dval );
    }
    
    /// QueryFloatAttribute examines the attribute - see QueryIntAttribute().
    int QueryFloatAttribute( char[] name, float* _value )
    {
        double d;
        int result = QueryDoubleAttribute( name, &d );
        if ( result == TIXML_SUCCESS ) {
            *_value = (float)d;
        }
        return result;
    }
    +/

    /** Sets an attribute of name to a given value. The attribute
        will be created if it does not exist, or changed if it does.
    */
    void SetAttribute( char[] name, char[]  _value )
    {
        TiXmlAttribute node = attributeSet.Find( name );
        if ( node !is null)
        {
            node.Value( _value );
            return;
        }
    
        TiXmlAttribute attrib = new TiXmlAttribute( name, _value );
        if ( attrib !is null )
        {
            attributeSet.Add( attrib );
        }
        else
        {
            TiXmlDocument document = GetDocument();
            if ( document !is null )
                document.SetError( TIXML_ERROR_OUT_OF_MEMORY, null, null, TiXmlEncoding.UNKNOWN );
        }
    }
  
    /** Sets an attribute of name to a given value. The attribute
        will be created if it does not exist, or changed if it does.
    */
    void SetAttribute( char[] name, int value )
    {   
        SetAttribute( name, std.string.toString(value));
    }

    /** Sets an attribute of name to a given value. The attribute
        will be created if it does not exist, or changed if it does.
    */
    void SetDoubleAttribute( char[]  name, double value )
    {   
        SetAttribute( name, std.string.toString(value));
    }

    /** Deletes an attribute with the given name.
    */
    void RemoveAttribute( char[]  name  )
    {
        TiXmlAttribute node = attributeSet.Find( name );
        if ( node !is null)
        {
            attributeSet.Remove( node );
            delete node;
        }
    }
    
    ///< Access the first attribute in this element.
    TiXmlAttribute FirstAttribute()                { return attributeSet.First(); }
    ///< Access the last attribute in this element.
    TiXmlAttribute LastAttribute()                 { return attributeSet.Last(); }

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
                 similarly named TiXmlHandle::Text() and TiXmlNode.ToText() which are 
                 safe type casts on the referenced node.
    */
    char[] GetText()
    {
        TiXmlNode child = this.FirstChild();
        if ( child !is null)
        {
            TiXmlText childText = child.ToText();
            if ( childText !is null ) {
                return childText.Value();
            }
        }
        return null;
    }
    /+
    /// Creates a new Element and returns it - the returned element is a copy.
    TiXmlNode Clone()
    {
        TiXmlElement* clone = new TiXmlElement( Value() );
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    +/
    
    // Print the Element to a FILE stream.
    char[] toString( int depth )
    {
        char[] str = std.string.repeat(" ", depth * 4);
        str ~= "<" ~ value;
   
        TiXmlAttribute attrib;
        for ( attrib = attributeSet.First(); attrib !is null; attrib = attrib.Next() )
        {
            str ~= " " ~ attrib.toString(depth);
        }
    
        // There are 3 different formatting approaches:
        // 1) An element without children is printed as a <foo /> node
        // 2) An element with only a text child is printed as <foo> text </foo>
        // 3) An element with children is printed on multiple lines.
        TiXmlNode node;
        if ( firstChild is null)
        {
            str ~= " />";
        }
        else if ( firstChild == lastChild && firstChild.ToText() !is null )
        {
            str ~= ">";
            str ~= firstChild.toString(depth + 1);
            str ~= "</" ~ value ~ ">";
        }
        else
        {
            str ~= ">";
    
            for ( node = firstChild; node !is null; node=node.NextSibling() )
            {
                if ( node.ToText() !is null)
                {
                    str ~= "\n";
                }
                str ~= node.toString(depth + 1);
            }
            str ~= "\n";
            str ~= std.string.repeat(" ", depth * 4);
            str ~= "</" ~ value ~ ">";
        }
    }

    /*  Attribtue parsing starts: next char past '<'
                         returns: next char past '>'
    */
    char[] Parse( char[] p, TiXmlParsingData data, TiXmlEncoding encoding )
    {
        TiXmlDocument document = GetDocument();

        p = SkipWhiteSpace( p, encoding );

        if ( p is null || p.length == 0 )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_ELEMENT, null, null, encoding );
            return null;
        }
    
        if ( data !is null )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
    
        if ( p[0] != '<' )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_ELEMENT, p, data, encoding );
            return null;
        }
    
        p = SkipWhiteSpace( p[1 .. $], encoding );

        if ( p is null || p.length == 0 )
        {
            if ( document ) document.SetError( TIXML_ERROR_PARSING_ELEMENT, null, null, encoding );
            return null;
        }

        // Read the name.
        char[] pErr = p;
    
            
        p = ReadName( p, value, encoding );
        if ( p is null || p.length == 0 )
        {
            if ( document ) document.SetError( TIXML_ERROR_FAILED_TO_READ_ELEMENT_NAME, pErr, data, encoding );
            return null;
        }

        char[] endTag = "</" ~ value ~ ">";
          
        // Check for and read attributes. Also look for an empty
        // tag or an end tag.
        while ( p.length > 0 )
        {
            pErr = p;
            p = SkipWhiteSpace( p, encoding );
            if ( p is null || p.length == 0 )
            {
                if ( document )
                    document.SetError( TIXML_ERROR_READING_ATTRIBUTES, pErr, data, encoding );
                return null;
            }

            if ( p[0] == '/' )
            {                
                // Empty tag.
                if ( p[1] != '>' )
                {
                    if ( document )
                        document.SetError( TIXML_ERROR_PARSING_EMPTY, p, data, encoding );     
                    return null;
                }
 
                return p[2..$]; //skip "/>"
            }
            else if ( p[0] == '>' )
            {
                // Done with attributes (if there were any.)
                // Read the value -- which can include other
                // elements -- read the end tag, and return.                
                p = ReadValue( p[1 .. $], data, encoding );     // Note this is an Element method, and will set the error if one happens.
                if ( p is null || p.length == 0 )
                    return null;
    
                // We should find the end tag now
                if ( StringEqual( p, endTag, false, encoding ) )
                {
                    return p[endTag.length .. $];
                }
                else
                {
                    if ( document )
                        document.SetError( TIXML_ERROR_READING_END_TAG, p, data, encoding );
                    return null;
                }
            }
            else
            {
                // Try to read an attribute:
                TiXmlAttribute attrib = new TiXmlAttribute();
                if ( attrib !is null)
                {
                    if ( document )
                        document.SetError( TIXML_ERROR_OUT_OF_MEMORY, pErr, data, encoding );
                    return null;
                }
    
                attrib.Document( document );
                char[] pErr = p;
                p = attrib.Parse( p, data, encoding );
    
                if ( p is null || p.length == 0 )
                {
                    if ( document )
                        document.SetError( TIXML_ERROR_PARSING_ELEMENT, pErr, data, encoding );
                    delete attrib;
                    return null;
                }
   
                // Handle the strange case of double attributes:
                TiXmlAttribute node = attributeSet.Find( attrib.Name() );
                if ( node is null )
                {
                    node.Value( attrib.Value() );
                    delete attrib;
                    return null;
                }
    
                attributeSet.Add( attrib );
            }
        }
        return p;
    }

protected:
    /+
    void CopyTo( TiXmlElement* target )
    {
        // superclass:
        TiXmlNode.CopyTo( target );
    
        // Element class: 
        // Clone the attributes, then clone the children.
        TiXmlAttribute* attribute = 0;
        for(    attribute = attributeSet.First();
        attribute;
        attribute = attribute.Next() )
        {
            target.SetAttribute( attribute.Name(), attribute.Value() );
        }
    
        TiXmlNode node = 0;
        for ( node = firstChild; node; node = node.NextSibling() )
        {
            target.LinkEndChild( node.Clone() );
        }
    }
    +/
    void ClearThis()    // like clear, but initializes 'this' object as well
    {
        Clear();
        while( attributeSet.First() !is null)
        {
            TiXmlAttribute node = attributeSet.First();
            attributeSet.Remove( node );
            delete node;
        }
    }
    
    /*  [internal use]
        Reads the "value" of the element -- another element, or text.
        This should terminate with the current end tag.
    */
    char[] ReadValue( char[] p, TiXmlParsingData prevData, TiXmlEncoding encoding )
    {
        TiXmlDocument document = GetDocument();
    
        // Read in text and elements in any order.
        char[] pWithWhiteSpace = p;
        p = SkipWhiteSpace( p, encoding );
    
        while ( p.length > 0 )
        {
            if ( p[0] != '<' )
            {
                // Take what we have, make a text element.
                TiXmlText textNode = new TiXmlText( "" );
    
                if ( textNode is null )
                {
                    if ( document )
                        document.SetError( TIXML_ERROR_OUT_OF_MEMORY, null, null, encoding );
                    return null;
                }
    
                //if ( TiXmlBase.IsWhiteSpaceCondensed() )
                {
                    p = textNode.Parse( p, prevData, encoding );
                }
                //else
                //{
                    // Special case: we want to keep the white space
                    // so that leading spaces aren't removed.
                //    p = textNode.Parse( pWithWhiteSpace, data, encoding );
                //}
    
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
                    TiXmlNode node = Identify( p, encoding );
                    if ( node )
                    {
                        p = node.Parse( p, prevData, encoding );
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
    
        if ( p is null )
        {
            if ( document ) 
                document.SetError( TIXML_ERROR_READING_ELEMENT_VALUE, null, null, encoding );
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
       super( TiXmlNode.NodeType.COMMENT );
    }

    /// Returns a copy of this Comment.
    /+
    TiXmlNode Clone()
    {
        TiXmlComment* clone = new TiXmlComment();
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    +/
    /// Write this Comment to a FILE stream.
    char[] toString( int depth )
    {
        return std.string.repeat(" ", depth * 4) ~ "<!--" ~ value ~ "-->";
    }

    /*  Attribtue parsing starts: at the ! of the !--
                         returns: next char past '>'
    */
    char[] Parse( char[] p, TiXmlParsingData data, TiXmlEncoding encoding )
    {
        TiXmlDocument document = GetDocument();
        value = "";
    
        p = SkipWhiteSpace( p, encoding );
    
        if ( data is null)
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
        char[] startTag = "<!--";
        char[] endTag   = "-->";
    
        if ( !StringEqual( p, startTag, false, encoding ) )
        {
            document.SetError( TIXML_ERROR_PARSING_COMMENT, p, data, encoding );
            return null;
        }

        return ReadText( p[startTag.length .. $], value, false, endTag, false, encoding );
    }

protected:
    /+
    void CopyTo( TiXmlComment* target )
    {
        TiXmlNode.CopyTo( target );
    }
    +/

}


/** XML text. A text node can have 2 ways to output the next. "normal" output 
    and CDATA. It will default to the mode it was parsed from the XML file and
    you generally want to leave it alone, but you can change the output mode with 
    SetCDATA() and query it with CDATA().
*/
class TiXmlText : public TiXmlNode
{
public:
    /** Constructor for text element. By default, it is treated as 
        normal, encoded text. If you want it be output as a CDATA text
        element, set the parameter _cdata to 'true'
    */
    this (char[] initValue )
    {
        super(TiXmlNode.NodeType.TEXT);
        Value( initValue );
        cdata = false;
    }   
    
    /// Write this text object to a FILE stream.
    char[] toString( int depth )
    {
        if ( cdata )
        {
            return "\n" ~ std.string.repeat(" ", depth * 4) ~ "<![CDATA[" ~ value ~ "]]>\n";
        }
        else
        {
            return value;
        }
    }

    /// Queries whether this represents text using a CDATA section.
    bool CDATA()                    { return cdata; }
    /// Turns on or off a CDATA representation of text.
    void SetCDATA( bool _cdata )    { cdata = _cdata; }

    char[] Parse( char[] p, TiXmlParsingData data, TiXmlEncoding encoding )
    {       
        value = "";
        TiXmlDocument document = GetDocument();
    
        if ( data !is null)
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
    
        char[] startTag = "<![CDATA[";
        char[] endTag   = "]]>";
    
        if ( cdata || StringEqual( p, startTag, false, encoding ) )
        {
            cdata = true;
    
            if ( !StringEqual( p, startTag, false, encoding ) )
            {
                document.SetError( TIXML_ERROR_PARSING_CDATA, p, data, encoding );
                return null;
            }

            // Keep all the white space, ignore the encoding, etc.
            int endIndex = std.string.ifind(p[startTag.length .. $], endTag);

            
            if(endIndex == -1)
            {
                return null;
            }
            value = p[startTag.length .. endIndex];

            char[] dummy;
            p = ReadText( p[endIndex .. $], dummy, false, endTag, false, encoding );
               
            return p;
        }
        else
        {
            bool ignoreWhite = true;
    
            char[] end = "<";
            char[] pOld = p;
            p = ReadText( p, value, ignoreWhite, end, false, encoding );
            
            if ( p !is null)
            {
                int beforeEndTag = pOld.length - p.length - 1;
                return pOld[beforeEndTag .. $]; // don't truncate the '<'
            }
            return null;
        }
    }


protected :
    /+
    ///  [internal use] Creates a new Element and returns it.
    virtual TiXmlNode Clone()
    {   
        TiXmlText* clone = 0;
        clone = new TiXmlText( "" );
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    void CopyTo( TiXmlText* target )
    {
        TiXmlNode.CopyTo( target );
        target.cdata = cdata;
    }


    virtual void StreamOut ( TIXML_OSTREAM * out )
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
    +/

    bool Blank() // returns true if all white space and new lines
    {
        foreach(char c; value)
        {
            if( !IsWhiteSpace(c))
            {
                return false;
            }
        }
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
    this()
    {
       super( TiXmlNode.NodeType.DECLARATION );
    }

    /// Construct.
    this(   char[] _version,
                        char[] _encoding,
                        char[] _standalone )
    {
        super( TiXmlNode.NodeType.DECLARATION );
 
        xml_version = _version;
        encoding = _encoding;
        standalone = _standalone;
    }

    /// Version. Will return an empty string if none was found.
    char[] Version()          { return xml_version; }
    /// Encoding. Will return an empty string if none was found.
    char[] Encoding()     { return encoding; }
    /// Is this a standalone document?
    char[] Standalone()       { return standalone; }

    /+
    /// Creates a copy of this Declaration and returns it.
    TiXmlNode Clone()
    {   
        TiXmlDeclaration* clone = new TiXmlDeclaration();
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    +/
    /// Print this declaration to a FILE stream.
    char[] toString(int depth )
    {
        char[] str ="<?xml ";
        if ( xml_version.length > 0)
            str ~= "version=\"" ~ xml_version ~ "\" ";

        if ( encoding.length > 0)
            str ~= "encoding=\"" ~ encoding ~ "\" ";
        
        if ( standalone.length > 0)
            str ~= "standalone=\"" ~ standalone ~ "\" ";

        str ~= "?>";
        return str;
    }

    char[] Parse( char[] p, TiXmlParsingData data, TiXmlEncoding _encoding )
    {
        p = SkipWhiteSpace( p, _encoding );
        // Find the beginning, find the end, and look for
        // the stuff in-between.
        TiXmlDocument document = GetDocument();
        if ( p is null || p.length == 0 || !StringEqual( p, "<?xml", true, _encoding ) )
        {
            if ( document )
                document.SetError( TIXML_ERROR_PARSING_DECLARATION, null, null, _encoding );
            return null;
        }
        if ( data !is null)
        {
            data.Stamp( p, _encoding );
            location = data.Cursor();
        }

        int endxml = std.string.find(p, '>');
        if(endxml  == -1)
            return null;
          
        char[] declare = p[5 .. endxml];
        
        xml_version = "1.0";
        encoding = "UTF-8";
        standalone = "yes";
  
        auto TiXmlAttribute attrib = new TiXmlAttribute;

        int begin = std.string.find( declare, "version");
        if ( begin != -1)
        {
            attrib.Parse( declare[begin .. $], data, _encoding );     
            xml_version = attrib.Value();
        }

        begin = std.string.find( declare, "encoding");
        if ( begin != -1)
        {
            attrib.Parse( declare[begin .. $], data, _encoding );     
            encoding = attrib.Value();
        }

        begin = std.string.find( declare, "standalone");
        if ( begin != -1)
        {
            attrib.Parse( declare[begin .. $], data, _encoding );     
            standalone = attrib.Value();
        }

        return p[endxml + 1 .. $];
    }

protected:
    /+
    void CopyTo( TiXmlDeclaration* target )
    {
        TiXmlNode.CopyTo( target );
    
        target.version = version;
        target.encoding = encoding;
        target.standalone = standalone;
    }
    // used to be public
    
    virtual void StreamOut ( TIXML_OSTREAM * out)
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
    +/

private:

    char[] xml_version;
    char[] encoding;
    char[] standalone;
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
    this()
    {
        super( TiXmlNode.NodeType.UNKNOWN );
    }
    /+
    /// Creates a copy of this Unknown and returns it.
    virtual TiXmlNode Clone()
    {
        TiXmlUnknown* clone = new TiXmlUnknown();
    
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    +/
    /// Print this Unknown to a FILE stream.
    char[] toString(int depth )
    {
        return std.string.repeat(" ", depth * 4) ~ "<" ~ value ~ ">";
    }


    char[] Parse( char[] p, TiXmlParsingData data, TiXmlEncoding encoding )
    {
        TiXmlDocument document = GetDocument();
        p = SkipWhiteSpace( p, encoding );
    
        if ( data !is null )
        {
            data.Stamp( p, encoding );
            location = data.Cursor();
        }
        if ( p is null || p.length == 0 || p[0] != '<' )
        {
            if ( document )
                document.SetError( TIXML_ERROR_PARSING_UNKNOWN, p, data, encoding );
            return null;
        }
        int endTag = std.string.find(p, '>');
        if(endTag == -1)
        {
            return null;
        }
        value = p[1 .. endTag];
        return p[endTag + 1 .. $];
    }

protected:
    /+
    void CopyTo( TiXmlUnknown* target )
    {
        TiXmlNode.CopyTo( target );
    }

    void StreamOut ( TIXML_OSTREAM * out )
    {
        (*stream) << "<" << value << ">";       // Don't use entities here! It is unknown.
    }
    +/
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
    this( char[]  documentName )
    {
        super( TiXmlNode.NodeType.DOCUMENT );
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
        if ( LoadFile( value, encoding ) )
            return true;
    
        return false;
    }
    /// Save a file using the current document value. Returns true if successful.
    bool SaveFile()
    {       
        if ( SaveFile( value ) )
            return true;
    
        return false;
    }
    /// Load a file using the given filename. Returns true if successful.
    bool LoadFile( char[]  filename, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
    {
        // Delete the existing data:
        Clear();
        location.Clear();

        value = filename;
        
        if ( std.file.exists(value) )
        {
            char[] buf = cast(char[])std.file.read(value);                              
    
            Parse(buf, null, encoding );

    
            if (  Error() )
                return false;
            else
                return true;
        }        
        SetError( TIXML_ERROR_OPENING_FILE, null, null, TiXmlEncoding.UNKNOWN );
        return false;
    }
    /// Save a file using the given filename. Returns true if successful.
    bool SaveFile( char[]  filename )
    {
        char[] buf;
        if ( useMicrosoftBOM ) 
        {
            buf ~= "\xef\xbb\xbf";
        }

        buf ~= toString(0);

        std.file.write(filename, buf);
        return true;
    }

    /** Parse the given null terminated block of xml data. Passing in an encoding to this
        method (either TiXmlEncoding.LEGACY or TiXmlEncoding.UTF8 will force TinyXml
        to use that encoding, regardless of what TinyXml might otherwise try to detect.
    */
    char[] Parse( char[] p, TiXmlParsingData prevData = null, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
    {
        ClearError();
    
        // Parse away, at the document level. Since a document
        // contains nothing but other tags, most of what happens
        // here is skipping white space.
        if ( p is null || p.length == 0 )
        {
            SetError( TIXML_ERROR_DOCUMENT_EMPTY, null, null, TiXmlEncoding.UNKNOWN );
            return null;
        }
    
        // Note that, for a document, this needs to come
        // before the while space skip, so that parsing
        // starts from the pointer we are given.
        TiXmlCursor location;
        if ( prevData !is null )
        {
            location.row = prevData.cursor.row;
            location.col = prevData.cursor.col;
        }
        else
        {
            location.row = 0;
            location.col = 0;
        }
        TiXmlParsingData data = new TiXmlParsingData( p, TabSize(), location.row, location.col );
        location = data.Cursor();
    
        if ( encoding == TiXmlEncoding.UNKNOWN )
        {
            // Check for the Microsoft UTF-8 lead bytes.            
            if (p[0 .. 3] == "\xef\xbb\xbf")
            {
                encoding = TiXmlEncoding.UTF8;
                useMicrosoftBOM = true;
                p = p[3..$];
            }            
        }
    
        p = SkipWhiteSpace( p, encoding );
        if ( p is null )
        {
            SetError( TIXML_ERROR_DOCUMENT_EMPTY, null, null, TiXmlEncoding.UNKNOWN );
            return null;
        }
    
        while ( p !is null && p.length > 0 )
        {
            TiXmlNode node = Identify( p, encoding );
            if ( node !is null )
            {
                p = node.Parse( p, data, encoding );
                LinkEndChild( node );                
            }
            else
            {
                break;
            }
    
            // Did we get encoding info?
            /+
            if (encoding == TiXmlEncoding.UNKNOWN && node.ToDeclaration() is null)
            {
                TiXmlDeclaration dec = node.ToDeclaration();
                char[] enc = dec.Encoding();
                assert( enc );
    
                if ( enc.length == 0)
                    encoding = TiXmlEncoding.UTF8;
                else if ( StringEqual( enc, "UTF-8", true, TiXmlEncoding.UNKNOWN ) )
                    encoding = TiXmlEncoding.UTF8;
                else if ( StringEqual( enc, "UTF8", true, TiXmlEncoding.UNKNOWN ) )
                    encoding = TiXmlEncoding.UTF8; // incorrect, but be nice
                else 
                    encoding = TiXmlEncoding.LEGACY;
            }
            +/
        }

        
 
        // Was this empty?
        if ( firstChild is null) {
            SetError( TIXML_ERROR_DOCUMENT_EMPTY, null, null, encoding );
            return null;
        }

        // All is well.
        return p;
    }

    /** Get the root element -- the only top level element -- of the document.
        In well formed XML, there should only be one. TinyXml is tolerant of
        multiple elements at the document level.
    */
    TiXmlElement RootElement()  { return FirstChildElement(); }

    /** If an error occurs, Error will be set to true. Also,
        - The ErrorId() will contain the integer identifier of the error (not generally useful)
        - The ErrorDesc() method will return the name of the error. (very useful)
        - The ErrorRow() and ErrorCol() will return the location of the error (if known)
    */  
    bool Error()                       { return error; }

    /// Contains a textual (english) description of the error if one occurs.
    char[]  ErrorDesc()    { return errorDesc; }

    /** Generally, you probably want the error string ( ErrorDesc() ). But if you
        prefer the ErrorId, this function will fetch it.
    */
    int ErrorId()                  { return errorId; }

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
    void TabSize( int _tabsize )     { tabsize = _tabsize; }

    int TabSize() { return tabsize; }

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

    /// Print this Document to a FILE stream.
    char[] toString(int depth = 0 )
    {
        char[] str;

        TiXmlNode node;
        for ( node = FirstChild(); node !is null; node = node.NextSibling() )
        {
            writefln("%s, %s", str, node !is null);
            str ~= node.toString(depth);
        }
        return str;
    }

    // [internal use]
    void SetError( int err, char[] errorLocation, TiXmlParsingData prevData, TiXmlEncoding encoding )
    {   
        // The first error in a chain is more accurate - don't set again!
        if ( error )
            return;
    
        assert( err > 0 && err < TIXML_ERROR_STRING_COUNT );
        error   = true;
        errorId = err;
        errorDesc = "error";// errorString[ errorId ];
    
        errorLocation.length = 0;
        if ( errorDesc !is null && prevData !is null)
        {
            prevData.Stamp( errorDesc, encoding );
            errorLocation = prevData.CursorString();
        }
    }

protected :
    /+
    virtual void StreamOut ( TIXML_OSTREAM * out) 
    {
         TiXmlNode node;
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
    virtual TiXmlNode Clone() 
    {
        TiXmlDocument* clone = new TiXmlDocument();
        if ( !clone )
            return null;
    
        CopyTo( clone );
        return clone;
    }
    
private:
    void CopyTo( TiXmlDocument* target ) 
    {
        TiXmlNode.CopyTo( target );
    
        target.error = error;
        target.errorDesc = errorDesc.c_str ();
    
        TiXmlNode node = 0;
        for ( node = firstChild; node; node = node.NextSibling() )
        {
            target.LinkEndChild( node.Clone() );
        }   
    }
    +/
private:
    bool error;
    int  errorId;
    char[] errorDesc;
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
    this(TiXmlNode _node )                 { this.node = _node; }

    /// Return a handle to the first child node.
    TiXmlHandle FirstChild()
    {
        if ( node !is null )
        {
            TiXmlNode child = node.FirstChild();
            if ( child !is null)
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }
    /// Return a handle to the first child node with the given name.
    TiXmlHandle FirstChild( char[]  value )
    {
        if ( node !is null )
        {
            TiXmlNode child = node.FirstChild( value );
            if ( child !is null)
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }
    /// Return a handle to the first child element.
    TiXmlHandle FirstChildElement()
    {
        if ( node !is null )
        {
            TiXmlElement child = node.FirstChildElement();
            if ( child !is null)
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }

    /// Return a handle to the first child element with the given name.
    TiXmlHandle FirstChildElement( char[]  value )
    {
        if ( node !is null )
        {
            TiXmlElement child = node.FirstChildElement( value );
            if ( child !is null)
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }

    /** Return a handle to the "index" child with the given name. 
        The first child is 0, the second 1, etc.
    */
    TiXmlHandle Child( char[] value, int count )
    {
        if ( node !is null )
        {
            int i;
            TiXmlNode child = node.FirstChild( value );
            for (   i=0;
                    child !is null && i<count;
                    child = child.NextSibling( value ), ++i )
            {
                // nothing
            }
            if ( child !is null)
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }

    /** Return a handle to the "index" child. 
        The first child is 0, the second 1, etc.
    */
    TiXmlHandle Child( int count )
    {
        if ( node !is null )
        {
            int i;
            TiXmlNode child = node.FirstChild();
            for (   i=0;
                    child !is null && i<count;
                    child = child.NextSibling(), ++i )
            {
                // nothing
            }
            if ( child !is null)
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }
    /** Return a handle to the "index" child element with the given name. 
        The first child element is 0, the second 1, etc. Note that only TiXmlElements
        are indexed: other types are not counted.
    */
    TiXmlHandle ChildElement( char[] value, int count )
    {
        if ( node !is null )
        {
            int i;
            TiXmlElement child = node.FirstChildElement( value );
            for (   i=0;
                    child !is null && i<count;
                    child = child.NextSiblingElement( value ), ++i )
            {
                // nothing
            }
            if ( child )
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }
    /** Return a handle to the "index" child element. 
        The first child element is 0, the second 1, etc. Note that only TiXmlElements
        are indexed: other types are not counted.
    */
    TiXmlHandle ChildElement( int count )
    {
        if ( node !is null )
        {
            int i;
            TiXmlElement child = node.FirstChildElement();
            for (   i=0;
                    child !is null && i<count;
                    child = child.NextSiblingElement(), ++i )
            {
                // nothing
            }
            if ( child !is null )
                return new TiXmlHandle( child );
        }
        return new TiXmlHandle(null);
    }


    /// Return the handle as a TiXmlNode. This may return null.
    TiXmlNode Node() 
    {
        return node;
    } 

    /// Return the handle as a TiXmlElement. This may return null.
    TiXmlElement Element()
    {
        if (node !is null)
        {
            return node.ToElement();
        }
        return null;        
    }
    /// Return the handle as a TiXmlText. This may return null.
    TiXmlText Text()
    {
        if (node !is null)
        {
            return node.ToText();
        }
        return null;        
    }

    /// Return the handle as a TiXmlUnknown. This may return null;
    TiXmlUnknown Unknown()
    {
        if (node !is null)
        {
            return node.ToUnknown();
        }
        return null;        
    }

private:
    TiXmlNode node;
}


class TiXmlParsingData
{   
public:
    void Stamp( char[] now, TiXmlEncoding encoding )
    {/+
        assert( now );
    
        // Do nothing if the tabsize is 0.
        if ( tabsize < 1 )
        {
            return;
        }
    
        // Get the current row, column.
        int row = cursor.row;
        int col = cursor.col;
        char[] p = stamp[0 .. stamp.length - now.length];
        //assert( p !is null);

        bool followedbyNewline = false;

        foreach(int i, dchar c; p)
        {
            switch(c)
            {
                case '\r':
                    if (followedbyNewline)
                    {
                        followedbyNewline = false;
                        break;
                    }
                    //fall down
                case '\n':
                    ++row;
                    col = 0;
      
                    // Check for \n\r sequence, and treat this as a single
                    // character.  (Yes, this bizarre thing does occur still
                    // on some arcane platforms...)
                    if (p[i + 1] == '\r') {
                        followedbyNewline = true;
                    }
                    break;
                case '\t':   
                    // Skip to next tab stop
                    col = (col / tabsize + 1) * tabsize;
                    break;    
                default:
                    ++col;
                    break;
            }   
        }
        cursor.row = row;
        cursor.col = col;
        assert( cursor.row >= -1 );
        assert( cursor.col >= -1 );
        stamp = p;
        assert( stamp );
        +/
    }

    TiXmlCursor Cursor() { return cursor; }
    char[] CursorString(){ return std.string.format("%d, %d", cursor.row, cursor.col); }

  private:
    // Only used by the document!
    this( char[] start, int _tabsize, int row, int col )
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

import std.stdio;

int main()
{
    TiXmlDocument doc = new TiXmlDocument;
    doc.LoadFile("test01.xml");
    writefln("ddir");

    doc.SaveFile("output.xml");

    writefln("%s %s", doc.ErrorId, doc.ErrorDesc());
    return 0;
}