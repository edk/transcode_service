

Paperclip.interpolates :remote_id_partition do |attachment, style|
  # Returns the id of the instance in a split path form. e.g. returns
  # 000/001/234 for an id of 1234.
  case id = attachment.instance.original_id
  when Integer
    ("%09d" % id).scan(/\d{3}/).join("/")
  when String
    ('%9.9s' % id).tr(" ", "0").scan(/.{3}/).join("/")
  else
    nil
  end
end
