#include <ruby.h>

#include "omi_interface.h"
#include "unique_ptr.h"

#include <iostream>
#include <sstream>

namespace
{
    MI_Char const JSON_TRUE[] = MI_T ("true");
    MI_Char const JSON_FALSE[] = MI_T ("false");

    MI_Char const JSON_MI_TYPE[] = MI_T ("MI_Type");
    MI_Char const JSON_MI_TIMESTAMP[] = MI_T ("MI_Timestamp");
    MI_Char const JSON_MI_INTERVAL[] = MI_T ("MI_Interval");
    MI_Char const JSON_CLASS_KEY[] = MI_T ("ClassName");

    MI_Char const JSON_YEAR[] = MI_T ("year");
    MI_Char const JSON_MONTH[] = MI_T ("month");
    MI_Char const JSON_DAY[] = MI_T ("day");
    MI_Char const JSON_HOUR[] = MI_T ("hour");
    MI_Char const JSON_MINUTE[] = MI_T ("minute");
    MI_Char const JSON_SECOND[] = MI_T ("second");
    MI_Char const JSON_MICROSECONDS[] = MI_T ("microseconds");
    MI_Char const JSON_UTC[] = MI_T ("utc");
    MI_Char const JSON_DAYS[] = MI_T ("days");
    MI_Char const JSON_HOURS[] = MI_T ("hours");
    MI_Char const JSON_MINUTES[] = MI_T ("minutes");
    MI_Char const JSON_SECONDS[] = MI_T ("seconds");

    MI_Char const JSON_LIST_START = MI_T ('[');
    MI_Char const JSON_LIST_END = MI_T (']');
    MI_Char const JSON_DICT_START = MI_T ('{');
    MI_Char const JSON_DICT_END = MI_T ('}');

    MI_Char const JSON_SEPARATOR = MI_T (',');
    MI_Char const JSON_START_STRING = MI_T ('\"');
    MI_Char const JSON_END_STRING = MI_T ('\"');
    MI_Char const JSON_PAIR_TOKEN = MI_T (':');

    MI_Char const JSON_DOUBLE_QUOTE[] = MI_T ("\\\"");
    MI_Char const JSON_BACK_SLASH[] = MI_T ("\\\\");
    MI_Char const JSON_FORWARD_SLASH[] = MI_T ("\\/");
    MI_Char const JSON_BACK_SPACE[] = MI_T ("\\b");
    MI_Char const JSON_FORM_FEED[] = MI_T ("\\f");
    MI_Char const JSON_NEWLINE[] = MI_T ("\\n");
    MI_Char const JSON_RETURN[] = MI_T ("\\r");
    MI_Char const JSON_TAB[] = MI_T ("\\t");



    template<typename char_t, typename traits>
    void
    instance_to_json (
        std::basic_ostream<char_t, traits>& strm,
        MI_Instance const& instance);

    template<
        typename char_t,
        typename traits>
    void
    value_to_json (
        std::basic_ostream<char_t, traits>& strm,
        MI_Value const& value,
        MI_Type const& type);

    template<typename T, size_t N>
    size_t
    card (T const (&)[N])
    {
        return N;
    }


    MI_Char const*
    char_to_json (
        MI_Char const& ch)
    {
        MI_Char const* out = NULL;
        switch (ch)
        {
            case MI_T ('\"'):
                out = JSON_DOUBLE_QUOTE;
                break;
            case MI_T ('\\'):
                out = JSON_BACK_SLASH;
                break;
            case MI_T ('/'):
                out = JSON_FORWARD_SLASH;
                break;
            case MI_T ('\b'):
                out = JSON_BACK_SPACE;
                break;
            case MI_T ('\f'):
                out = JSON_FORM_FEED;
                break;
            case MI_T ('\n'):
                out = JSON_NEWLINE;
                break;
            case MI_T ('\r'):
                out = JSON_RETURN;
                break;
            case MI_T ('\t'):
                out = JSON_TAB;
                break;
            default:
                break;
        }
        return out;
    }


    template<
        typename char_t,
        typename traits>
    void
    string_to_json (
        std::basic_ostream<char_t, traits>& strm,
        MI_Char const* const str)
    {
        for (MI_Char const* ch = str; char_t ('\0') != *ch; ++ch)
        {
            MI_Char const* replacement = char_to_json (*ch);
            if (NULL != replacement)
            {
                strm << replacement;
            }
            else
            {
                strm << *ch;
            }
        }
    }


    template<
        typename char_t,
        typename traits,
        typename array_t>
    void
    array_to_json (
        std::basic_ostream<char_t, traits>& strm,
        array_t const& array,
        MI_Type const& type)
    {
        for (MI_Uint32 i = 0; i < array.size; ++i)
        {
            if (0 != i)
            {
                strm << JSON_SEPARATOR;
            }
            value_to_json (
                strm,
                *(reinterpret_cast<MI_Value const*>(array.data + i)),
                MI_Type (type & ~MI_ARRAY));
        }
    }


    template<
        typename char_t,
        typename traits>
    std::basic_ostream<char_t, traits>&
    operator << (
        std::basic_ostream<char_t, traits>& strm,
        MI_Timestamp timestamp)
    {
        // type
        strm << JSON_DICT_START
             << JSON_START_STRING << JSON_MI_TYPE << JSON_END_STRING
             << JSON_PAIR_TOKEN << JSON_START_STRING << JSON_MI_TIMESTAMP << JSON_END_STRING
             << JSON_SEPARATOR;
        // year
        strm << JSON_START_STRING << JSON_YEAR << JSON_END_STRING << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.year << JSON_END_STRING
             << JSON_SEPARATOR;
        // month
        strm << JSON_START_STRING << JSON_MONTH << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.month << JSON_END_STRING
             << JSON_SEPARATOR;
        // day
        strm << JSON_START_STRING << JSON_DAY << JSON_END_STRING << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.day << JSON_END_STRING
             << JSON_SEPARATOR;
        // hour
        strm << JSON_START_STRING << JSON_HOUR << JSON_END_STRING << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.hour << JSON_END_STRING
             << JSON_SEPARATOR;
        // minute
        strm << JSON_START_STRING << JSON_MINUTE << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.minute << JSON_END_STRING
             << JSON_SEPARATOR;
        // second
        strm << JSON_START_STRING << JSON_SECOND << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.second << JSON_END_STRING
             << JSON_SEPARATOR;
        // microseconds
        strm << JSON_START_STRING << JSON_MICROSECONDS << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.microseconds << JSON_END_STRING
             << JSON_SEPARATOR;
        // utc
        strm << JSON_START_STRING << JSON_UTC << JSON_END_STRING << JSON_PAIR_TOKEN
             << JSON_START_STRING << timestamp.utc << JSON_END_STRING
             << JSON_DICT_END;
        return strm;
    }


    template<
        typename char_t,
        typename traits>
    std::basic_ostream<char_t, traits>&
    operator << (
        std::basic_ostream<char_t, traits>& strm,
        MI_Interval interval)
    {
        // type
        strm << JSON_DICT_START
             << JSON_START_STRING << JSON_MI_TYPE << JSON_END_STRING
             << JSON_PAIR_TOKEN << JSON_START_STRING << JSON_MI_INTERVAL << JSON_END_STRING
             << JSON_SEPARATOR;
        // days
        strm << JSON_START_STRING << JSON_DAYS << JSON_END_STRING << JSON_PAIR_TOKEN
             << JSON_START_STRING << interval.days << JSON_END_STRING
             << JSON_SEPARATOR;
        // hours
        strm << JSON_START_STRING << JSON_HOURS << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << interval.hours << JSON_END_STRING
             << JSON_SEPARATOR;
        // minutes
        strm << JSON_START_STRING << JSON_MINUTES << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << interval.minutes << JSON_END_STRING
             << JSON_SEPARATOR;
        // seconds
        strm << JSON_START_STRING << JSON_SECONDS << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << interval.seconds << JSON_END_STRING
             << JSON_SEPARATOR;
        // microseconds
        strm << JSON_START_STRING << JSON_MICROSECONDS << JSON_END_STRING
             << JSON_PAIR_TOKEN
             << JSON_START_STRING << interval.microseconds << JSON_END_STRING
             << JSON_SEPARATOR;
        return strm;
    }


    template<
        typename char_t,
        typename traits>
    void
    value_to_json (
        std::basic_ostream<char_t, traits>& strm,
        MI_Value const& value,
        MI_Type const& type)
    {
        if (MI_ARRAY & type)
        {
            strm << JSON_LIST_START;
        }
        else if (type != MI_DATETIME)
        {
            strm << JSON_START_STRING;
        }

        switch (type)
        {
            case MI_BOOLEAN:
                strm << (MI_FALSE == value.boolean ? JSON_FALSE : JSON_TRUE);
                break;
            case MI_UINT8:
                strm << static_cast<unsigned int>(value.uint8);
                break;
            case MI_SINT8:
                strm << static_cast<int>(value.sint8);
                break;
            case MI_UINT16:
                strm << value.uint16;
                break;
            case MI_SINT16:
                strm << value.sint16;
                break;
            case MI_UINT32:
                strm << value.uint32;
                break;
            case MI_SINT32:
                strm << value.sint32;
                break;
            case MI_UINT64:
                strm << value.uint64;
                break;
            case MI_SINT64:
                strm << value.sint64;
                break;
            case MI_REAL32:
                strm << value.real32;
                break;
            case MI_REAL64:
                strm << value.real64;
                break;
            case MI_CHAR16:
                strm << value.char16;
                break;
            case MI_DATETIME:
                if (value.datetime.isTimestamp)
                {
                    strm << value.datetime.u.timestamp;
                }
                else
                {
                    strm << value.datetime.u.interval;
                }
                break;
            case MI_STRING:
                string_to_json (strm, value.string);
                break;
            case MI_REFERENCE:
                instance_to_json (strm, *(value.reference));
                break;
            case MI_INSTANCE:
                instance_to_json (strm, *(value.instance));
                break;
            case MI_BOOLEANA:
                array_to_json (strm, value.booleana, type);
                break;
            case MI_UINT8A:
                array_to_json (strm, value.uint8a, type);
                break;
            case MI_SINT8A:
                array_to_json (strm, value.sint8a, type);
                break;
            case MI_UINT16A:
                array_to_json (strm, value.uint16a, type);
                break;
            case MI_SINT16A:
                array_to_json (strm, value.sint16a, type);
                break;
            case MI_UINT32A:
                array_to_json (strm, value.uint32a, type);
                break;
            case MI_SINT32A:
                array_to_json (strm, value.sint32a, type);
                break;
            case MI_UINT64A:
                array_to_json (strm, value.uint64a, type);
                break;
            case MI_SINT64A:
                array_to_json (strm, value.sint64a, type);
                break;
            case MI_REAL32A:
                array_to_json (strm, value.real32a, type);
                break;
            case MI_REAL64A:
                array_to_json (strm, value.real64a, type);
                break;
            case MI_CHAR16A:
                array_to_json (strm, value.char16a, type);
                break;
            case MI_DATETIMEA:
                array_to_json (strm, value.datetimea, type);
                break;
            case MI_STRINGA:
                array_to_json (strm, value.stringa, type);
                break;
            case MI_REFERENCEA:
            case MI_INSTANCEA:
                array_to_json (strm, value.instancea, type);
                break;
        }

        if (MI_ARRAY & type)
        {
            strm << JSON_LIST_END;
        }
        else if (type != MI_DATETIME)
        {
            strm << JSON_END_STRING;
        }
    }


    template<typename char_t, typename traits>
    void
    instance_to_json (
        std::basic_ostream<char_t, traits>& strm,
        MI_Instance const& instance)
    {
        // An instance should be formated in a dictionary that is valid JSON
        // Here is a partial example for the SCX_OperatingSystem class
        /*
        {
            "ClassName": "SCX_OperatingSystem",
            "Name": "Linux Distribution",
            "LastBootUpTime": {
                "MI_Type": "MI_Timestamp",
                "year": "2015",
                "month": "8",
                "day": "19",
                "hour": "10",
                "minute": "57",
                "second": "14",
                "microseconds": "0",
                "utc": "0"
            },
            "SystemUpTime": "3567851"
        }*/

        MI_Char const* className;
        MI_Uint32 count;
        if (MI_RESULT_OK == MI_Instance_GetClassName (&instance, &className) &&
            MI_RESULT_OK == MI_Instance_GetElementCount (&instance, &count))
        {
            strm << JSON_DICT_START
                 << JSON_START_STRING << JSON_CLASS_KEY << JSON_END_STRING
                 << JSON_PAIR_TOKEN << JSON_START_STRING << className << JSON_END_STRING;
            for (MI_Uint32 i = 0; i < count; ++i)
            {
                MI_Char const* elementName;
                MI_Value value;
                MI_Type type;
                MI_Uint32 flags;
                if (MI_RESULT_OK == MI_Instance_GetElementAt (
                        &instance, i, &elementName, &value, &type, &flags) &&
                    0 == (MI_FLAG_NULL & flags))
                {
                    strm << JSON_SEPARATOR;
                    strm << JSON_START_STRING;
                    string_to_json (strm, elementName);
                    strm << JSON_END_STRING << JSON_PAIR_TOKEN;
                    value_to_json (strm, value, type);
                }
            }
            strm << JSON_DICT_END;
        }
    }


    template<typename char_t, typename traits>
    int
    handle_results (
        std::basic_ostream<char_t, traits>& strm,
        MI_Operation* const operation)
    {
        int count = 0;
        MI_Result result = MI_RESULT_OK;
        MI_Boolean moreRemaining = MI_TRUE;
        do
        {
            MI_Instance const* pInstance = NULL;
            MI_Result instanceResult = MI_Operation_GetInstance (
                operation, &pInstance, &moreRemaining, &result, NULL, NULL);
            if (MI_RESULT_OK == instanceResult &&
                NULL != pInstance)
            {
                if (0 < count)
                {
                    strm << JSON_SEPARATOR;
                }
                instance_to_json (strm, *pInstance);
                ++count;
            }
        } while (MI_RESULT_OK == result &&
                 MI_TRUE == moreRemaining);
        return count;
    }


    OMIInterface*
    get_OMIInterface (
        VALUE self);


    void
    wrap_OMIInterface_free (
        OMIInterface* pInterface);


    VALUE
    wrap_OMIInterface_alloc (
        VALUE _class);


    VALUE
    wrap_OMIInterface_init (
        VALUE self);


    VALUE
    wrap_OMIInterface_toString (
        VALUE self);


    VALUE
    wrap_OMIInterface_connect (
        VALUE self);


    VALUE
    wrap_OMIInterface_disconnect (
        VALUE self);


    VALUE
    wrap_OMIInterface_enumerate (
        VALUE self,
        VALUE items);

}


extern "C" {

    void
    Init_Libomi ()
    {
        VALUE myModule = rb_define_module ("Libomi");
        VALUE omiInterface =
        rb_define_class_under (myModule, "OMIInterface", rb_cObject);
        rb_define_alloc_func (omiInterface, wrap_OMIInterface_alloc);
        rb_define_method (
            omiInterface, "initialize", RUBY_METHOD_FUNC (wrap_OMIInterface_init),
            0);
        rb_define_method (
            omiInterface, "inspect", RUBY_METHOD_FUNC (wrap_OMIInterface_toString),
            0);
        rb_define_method (
            omiInterface, "to_s", RUBY_METHOD_FUNC (wrap_OMIInterface_toString), 0);
        rb_define_method (
            omiInterface, "connect", RUBY_METHOD_FUNC (wrap_OMIInterface_connect),
            0);
        rb_define_method (
            omiInterface, "disconnect",
            RUBY_METHOD_FUNC (wrap_OMIInterface_disconnect), 0);
        rb_define_method (
            omiInterface, "enumerate",
            RUBY_METHOD_FUNC (wrap_OMIInterface_enumerate), 1);
    }

}


/*ctor*/
OMIInterface::OMIInterface ()
    : m_App ()
    , m_Session ()
    , m_Options ()
{
    MI_Application _app = MI_APPLICATION_NULL;
    memcpy (&m_App, &_app, sizeof (MI_Application));
    MI_Session _session = MI_SESSION_NULL;
    memcpy (&m_Session, &_session, sizeof (MI_Session));
    MI_OperationOptions _options = MI_OPERATIONOPTIONS_NULL;
    memcpy (&m_Options, &_options, sizeof (MI_OperationOptions));
}


/*dtor*/
OMIInterface::~OMIInterface ()
{
    Disconnect ();
}


MI_Result
OMIInterface::Connect ()
{
    util::unique_ptr<MI_Instance, MI_Result (*)(MI_Instance*)> pError (
        NULL, MI_Instance_Delete);
    MI_Instance* pTemp = NULL;
    MI_Result result = MI_Application_Initialize (0, NULL, &pTemp, &m_App);
    pError.reset (pTemp);
    if (MI_RESULT_OK == result)
    {
        result = MI_Application_NewSession (
            &m_App, NULL, NULL, NULL, NULL, &pTemp, &m_Session);
        pError.reset (pTemp);
        if (MI_RESULT_OK == result)
        {
            result = MI_Application_NewOperationOptions (
                &m_App, MI_FALSE, &m_Options);
            if (MI_RESULT_OK == result)
            {
                MI_Interval timeoutInterval;
                memset (&timeoutInterval, 0, sizeof (MI_Interval));
                timeoutInterval.seconds = 30;
                timeoutInterval.minutes = 1;
                result = MI_OperationOptions_SetTimeout (
                    &m_Options, &timeoutInterval);
            }
        }
    }
    if (MI_RESULT_OK != result)
    {
        Disconnect ();
    }
    return result;
}


void
OMIInterface::Disconnect ()
{
    MI_OperationOptions_Delete (&m_Options);
    MI_OperationOptions _options = MI_OPERATIONOPTIONS_NULL;
    memcpy (&m_Options, &_options, sizeof (MI_OperationOptions));
    MI_Session_Close (&m_Session, NULL, NULL);
    MI_Session _session = MI_SESSION_NULL;
    memcpy (&m_Session, &_session, sizeof (MI_Session));
    MI_Application_Close (&m_App);
    MI_Application _app = MI_APPLICATION_NULL;
    memcpy (&m_App, &_app, sizeof (MI_Application));
}


template<typename char_t, typename traits>
MI_Result
OMIInterface::Enumerate (
    std::basic_ostream<char_t, traits>& strm,
    std::vector<std::pair <char_t const*, char_t const*> >& enumItems)
{
    typedef std::pair<char_t const*, char_t const*> EnumItem_t;
    MI_Result result = MI_RESULT_OK;
    bool addSeparator = false;
    strm << JSON_LIST_START;
    for (typename std::vector<EnumItem_t>::iterator pos = enumItems.begin (),
         endPos = enumItems.end ();
         pos != endPos;
         ++pos)
    {
        MI_Uint32 flags = 0;
        MI_Operation operation = MI_OPERATION_NULL;
        MI_Session_EnumerateInstances (
            &m_Session,
            flags,
            &m_Options,
            pos->first,
            pos->second,
            MI_FALSE,
            NULL,
            &operation);
        if (addSeparator)
        {
            strm << JSON_SEPARATOR;
        }
        addSeparator = (0 < handle_results (strm, &operation));
        MI_Operation_Close (&operation);
    }
    strm << JSON_LIST_END;
    return result;
}


namespace
{
    OMIInterface*
    get_OMIInterface (
        VALUE self)
    {
        OMIInterface* ptr;
        Data_Get_Struct (self, OMIInterface, ptr);
        return ptr;
    }


    void
    wrap_OMIInterface_free (
        OMIInterface* pInterface)
    {
        if (0 != pInterface)
        {
            pInterface->~OMIInterface ();
            ruby_xfree (pInterface);
        }
    }


    VALUE
    wrap_OMIInterface_alloc (
        VALUE _class)
    {
        return Data_Wrap_Struct (
            _class, NULL, wrap_OMIInterface_free,
            ruby_xmalloc (sizeof (OMIInterface)));
    }


    VALUE
    wrap_OMIInterface_init (
        VALUE self)
    {
        OMIInterface* pInterface = get_OMIInterface (self);
        new (pInterface) OMIInterface ();
        return Qnil;
    }


    VALUE
    wrap_OMIInterface_toString (
        VALUE self)
    {
        return rb_str_new2 ("OMIInterface");
    }


    VALUE
    wrap_OMIInterface_connect (
        VALUE self)
    {
        OMIInterface* pInterface = get_OMIInterface (self);
        return INT2FIX (pInterface->Connect ());
    }


    VALUE
    wrap_OMIInterface_disconnect (
        VALUE self)
    {
        OMIInterface* pInterface = get_OMIInterface (self);
        pInterface->Disconnect ();
        return Qnil;
    }


    VALUE
    wrap_OMIInterface_enumerate (
        VALUE self,
        VALUE items)
    {
        typedef std::pair<MI_Char const*, MI_Char const*> EnumItem_t;
        std::basic_ostringstream<MI_Char> strm;
        if (T_ARRAY == TYPE (items))
        {
            int length = RARRAY_LEN (items);
            std::vector<EnumItem_t> enumItems;
            for (int i = 0; i < length; ++i)
            {
                VALUE item = RARRAY_AREF (items, i);
                if (T_ARRAY == TYPE (item) &&
                    2 == RARRAY_LEN (item) &&
                    T_STRING == TYPE (RARRAY_AREF (item, 0)) &&
                    T_STRING == TYPE (RARRAY_AREF (item, 1)))
                {
                    enumItems.push_back (EnumItem_t (
                                             RSTRING_PTR (RARRAY_AREF (item, 0)),
                                             RSTRING_PTR (RARRAY_AREF (item, 1))));
                }
            }
            OMIInterface* pInterface = get_OMIInterface (self);
            pInterface->Enumerate (strm, enumItems);
        }
        return rb_str_new2 (strm.str ().c_str ());
    }
}
