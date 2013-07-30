/**
 * Autogenerated by Thrift Compiler (0.9.0)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
#ifndef attrs_TYPES_H
#define attrs_TYPES_H

#include <thrift/Thrift.h>
#include <thrift/TApplicationException.h>
#include <thrift/protocol/TProtocol.h>
#include <thrift/transport/TTransport.h>





typedef struct _Flags__isset {
  _Flags__isset() : io(false), omit(false) {}
  bool io;
  bool omit;
} _Flags__isset;

class Flags {
 public:

  static const char* ascii_fingerprint; // = "1959DF646639D95C0F1375CF60F71F5B";
  static const uint8_t binary_fingerprint[16]; // = {0x19,0x59,0xDF,0x64,0x66,0x39,0xD9,0x5C,0x0F,0x13,0x75,0xCF,0x60,0xF7,0x1F,0x5B};

  Flags() : io(0), omit(0) {
  }

  virtual ~Flags() throw() {}

  bool io;
  bool omit;

  _Flags__isset __isset;

  void __set_io(const bool val) {
    io = val;
    __isset.io = true;
  }

  void __set_omit(const bool val) {
    omit = val;
    __isset.omit = true;
  }

  bool operator == (const Flags & rhs) const
  {
    if (__isset.io != rhs.__isset.io)
      return false;
    else if (__isset.io && !(io == rhs.io))
      return false;
    if (__isset.omit != rhs.__isset.omit)
      return false;
    else if (__isset.omit && !(omit == rhs.omit))
      return false;
    return true;
  }
  bool operator != (const Flags &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Flags & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Flags &a, Flags &b);

typedef struct _Attributes__isset {
  _Attributes__isset() : spaces(false) {}
  bool spaces;
} _Attributes__isset;

class Attributes {
 public:

  static const char* ascii_fingerprint; // = "951945F8453D39BB0F43C336D8A2E43A";
  static const uint8_t binary_fingerprint[16]; // = {0x95,0x19,0x45,0xF8,0x45,0x3D,0x39,0xBB,0x0F,0x43,0xC3,0x36,0xD8,0xA2,0xE4,0x3A};

  Attributes() {
  }

  virtual ~Attributes() throw() {}

  std::map<std::string, std::map<std::string, std::string> >  spaces;

  _Attributes__isset __isset;

  void __set_spaces(const std::map<std::string, std::map<std::string, std::string> > & val) {
    spaces = val;
    __isset.spaces = true;
  }

  bool operator == (const Attributes & rhs) const
  {
    if (__isset.spaces != rhs.__isset.spaces)
      return false;
    else if (__isset.spaces && !(spaces == rhs.spaces))
      return false;
    return true;
  }
  bool operator != (const Attributes &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Attributes & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Attributes &a, Attributes &b);



#endif
