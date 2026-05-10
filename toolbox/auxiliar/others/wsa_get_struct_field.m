function val = wsa_get_struct_field(s, fieldname)
    if isfield(s, fieldname)
        val = s.(fieldname);
    else
        val = [];
    end
end