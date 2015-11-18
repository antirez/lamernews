# Modified by Salvatore Sanfilippo to only support HMAC-SHA1 from
# ruby-hmac gem in order to drop the openssl dependency.
#
# Copyright (c) 2008 Sam Quigley <quigley@emerose.com>
# Copyright (c) 2011 Salvatore Sanfilippo <antirez@gmail.com>
#  
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#  
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#  
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 
# This license is sometimes referred to as "The MIT License"

require 'rubygems'
require 'hmac-sha1'

class PBKDF2
  def initialize(opts={})
    # override with options
    opts.each_key do |k|
      if self.respond_to?("#{k}=")
        self.send("#{k}=", opts[k])
      else
        raise ArgumentError, "Argument '#{k}' is not allowed"
      end
    end
    
    yield self if block_given?

    # set this to the default if nothing was given
    @key_length ||= 20
    
    # make sure the relevant things got set
    raise ArgumentError, "password not set" if @password.nil?
    raise ArgumentError, "salt not set" if @salt.nil?
    raise ArgumentError, "iterations not set" if @iterations.nil?
  end
  attr_reader :key_length, :iterations, :salt, :password
  
  def key_length=(l)
    raise ArgumentError, "key too short" if l < 1
    raise ArgumentError, "key too long" if l > ((2**32 - 1) * 20)
    @value = nil
    @key_length = l
  end
  
  def iterations=(i)
    raise ArgumentError, "iterations can't be less than 1" if i < 1
    @value = nil
    @iterations = i
  end
  
  def salt=(s)
    @value = nil
    @salt = s
  end
  
  def password=(p)
    @value = nil
    @password = p
  end
  
  def value
    calculate! if @value.nil?
    @value
  end    
  
  alias bin_string value
    
  def hex_string
    bin_string.unpack("H*").first
  end
  
  # return number of milliseconds it takes to complete one iteration
  def benchmark(iters = 400000)
    iter_orig = @iterations
    @iterations=iters
    start = Time.now
    calculate!
    time = Time.now - start
    @iterations = iter_orig
    return (time/iters)
  end
  
  protected
  
  # the pseudo-random function defined in the spec
  def prf(data)
    if defined?(OpenSSL)
      OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new("sha1"),@password,data)
    else
      HMAC::SHA1.digest(@password,data)
    end
  end
  
  # this is a translation of the helper function "F" defined in the spec
  def calculate_block(block_num)
    # u_1:
    u = prf(salt+[block_num].pack("N"))
    ret = u
    # u_2 through u_c:
    2.upto(@iterations) do
      # calculate u_n
      u = prf(u)
      # xor it with the previous results
      ret = ret^u
    end
    ret
  end

  # the bit that actually does the calculating
  def calculate!
    # how many blocks we'll need to calculate (the last may be truncated)
    blocks_needed = (@key_length.to_f / 20).ceil
    # reset
    @value = ""
    # main block-calculating loop:
    1.upto(blocks_needed) do |block_num|
     @value << calculate_block(block_num)
    end
    # truncate to desired length:
    @value = @value.slice(0,@key_length)
    @value
  end
end

class String
  if RUBY_VERSION >= "1.9"
    def xor_impl(other)
      result = "".encode("ASCII-8BIT")
      o_bytes = other.bytes.to_a
      bytes.each_with_index do |c, i|
        result << (c ^ o_bytes[i])
      end
      result
    end
  else
    def xor_impl(other)
      result = (0..self.length-1).collect { |i| self[i] ^ other[i] }
      result.pack("C*")
    end
  end

  private :xor_impl

  def ^(other)
    raise ArgumentError, "Can't bitwise-XOR a String with a non-String" \
      unless other.kind_of? String
    raise ArgumentError, "Can't bitwise-XOR strings of different length" \
      unless self.length == other.length

    xor_impl(other)
  end
end
