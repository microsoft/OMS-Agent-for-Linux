#ifndef INCLUDE_OMI_INTERFACE_H
#define INCLUDE_OMI_INTERFACE_H


#include <MI.h>


#include <iosfwd>
#include <string>
#include <utility>
#include <vector>


class OMIInterface
{
public:
    /*ctor*/ OMIInterface ();
    /*dtor*/ ~OMIInterface ();

    MI_Result Connect ();
    void Disconnect ();

    template<typename char_t, typename traits>
    MI_Result Enumerate (
        std::basic_ostream<char_t, traits>& strm,
        std::vector<std::pair<char_t const*, char_t const*> >& enumItems);

private:
    /*ctor*/ OMIInterface (OMIInterface const&); // = delete
    OMIInterface& operator = (OMIInterface const&); // = delete

    MI_Application m_App;
    MI_Session m_Session;
    MI_OperationOptions m_Options;
};


#endif // INCLUDE_OMI_INTERFACE_H
