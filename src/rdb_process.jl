###Xiaobai
type RDB_Message
    header::RDB_MSG_HDR_t
    entry_headers::Vector{RDB_MSG_ENTRY_HDR_t}
    entries::Vector{RDB_PACKAGE_ELEMENT}
end

function Base.read(io::IO, ::Type{RDB_Message}, already_read_magic_no::Bool=false)
    header = read(io, RDB_MSG_HDR_t, already_read_magic_no)
    #println(header)
    entry_headers = RDB_MSG_ENTRY_HDR_t[]
    entries = RDB_PACKAGE_ELEMENT[]

    bytes_remaining = header.dataSize
    while bytes_remaining > 0
        entry_header = read(io, RDB_MSG_ENTRY_HDR_t)
        push!(entry_headers, entry_header)
        bytes_remaining -= entry_header.headerSize

        entry_type=rdb_pkg_id_to_type(entry_header.pkgId)
        element_num=entry_header.dataSize/entry_header.elementSize
        #println(entry_header)
        #println("entry type : ", entry_type)
        if entry_type == RDB_START_OF_FRAME_t
            entry = RDB_START_OF_FRAME_t()
            push!(entries, entry)
        elseif entry_type == RDB_END_OF_FRAME_t
            entry = RDB_END_OF_FRAME_t()
            push!(entries, entry)
        elseif entry_type != "UNKNOWN"
            for i=1:element_num
                entry = read(io, entry_type)
                #println("entry : ",entry)
                bytes_remaining -= entry_header.elementSize
                push!(entries, entry)
            end
        else
            break
        end     
    end

    RDB_Message(header, entry_headers, entries)
end


function processNFrame(N::Int=10,udp_entries::Array{RDB_PACKAGE_ELEMENT}=Array(RDB_PACKAGE_ELEMENT,0))
    entries=nothing
    for i=1:N
        entries=processOneFrame(udp_entries)
    end
    return entries
end
###Xiaobai

function processOneFrame(udp_entries::Array{RDB_PACKAGE_ELEMENT}=Array(RDB_PACKAGE_ELEMENT,0))
    #println("bytes available : ",nb_available(connection.UDP))
    #readbytes(connection.UDP, nb_available(connection.UDP))
    payload="<SimCtrl> <Step size=\"1\"/> </SimCtrl>"
    #payload=@sprintf("<SimCtrl> <Sync dt=\"%.2f\"/> </SimCtrl>", dt)
    SCPmessage=SCPMessage(payload)
    connection=ViresConnection()
    if length(udp_entries)>0
        VirtualTestDrive.write_udp_packets(connection.UDP, udp_entries, 0, 0.0)
    end
    write(connection.SCP, SCPmessage)
    
    
    finish=false
    entries=[]
    
    while !finish
        message=read(connection.UDP,VirtualTestDrive.RDB_Message)    
        if isempty(message.entry_headers)
            break
        end

        if VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="END_OF_FRAME"
            push!(entries,VirtualTestDrive.RDB_END_OF_FRAME_t())
        elseif VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="START_OF_FRAME"
            push!(entries,VirtualTestDrive.RDB_START_OF_FRAME_t())
        else
            push!(entries,message.entries)
        end
    
        if VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="END_OF_FRAME"
            # if udp_entry != nothing
            #     VirtualTestDrive.write_udp_packet(connection.UDP, udp_entry, message.header.frameNo, message.header.simTime)
            # end
            finish=true
        end
    end
    #write(connection.SCP, SCPmessage)
    disconnect!(connection)
    return entries
end

function processOneFrame_debug(udp_entries::Array{RDB_PACKAGE_ELEMENT}=Array(RDB_PACKAGE_ELEMENT,0))
    #println("bytes available : ",nb_available(connection.UDP))
    #readbytes(connection.UDP, nb_available(connection.UDP))
    payload="<SimCtrl> <Step size=\"1\"/> </SimCtrl>"
    #payload=@sprintf("<SimCtrl> <Sync dt=\"%.2f\"/> </SimCtrl>", dt)
    SCPmessage=SCPMessage(payload)
    connection=ViresConnection()
    if length(udp_entries)>0
        VirtualTestDrive.write_udp_packets(connection.UDP, udp_entries, 0, 0.0)
    end
    write(connection.SCP, SCPmessage)
    
    
    finish=false
    entries=[]
    message=nothing
    while !finish
        message=read(connection.UDP,VirtualTestDrive.RDB_Message)    
        if isempty(message.entry_headers)
            break
        end
        if VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="END_OF_FRAME"
            push!(entries,VirtualTestDrive.RDB_END_OF_FRAME_t())
        elseif VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="START_OF_FRAME"
            push!(entries,VirtualTestDrive.RDB_START_OF_FRAME_t())
        else
            push!(entries,message.entries)
        end
    
        if VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="END_OF_FRAME"
            # if udp_entry != nothing
            #     VirtualTestDrive.write_udp_packet(connection.UDP, udp_entry, message.header.frameNo, message.header.simTime)
            # end
            finish=true
        end
    end
    #write(connection.SCP, SCPmessage)
    disconnect!(connection)
    return message
end


function processOneFrameContinuous(udp_entry=nothing,connection=nothing)
    external_connect = true
    if connection == nothing
        external_connect = false
        connection=ViresConnection()
    end
    if udp_entry != nothing
        VirtualTestDrive.write_udp_packet(connection.UDP, udp_entry, 0, 0.0)
    end
    
    finish=false
    entries=VirtualTestDrive.RDB_PACKAGE_ELEMENT[]
    
    while !finish
        message=read(connection.UDP,VirtualTestDrive.RDB_Message)    
        if isempty(message.entry_headers)
            break
        end
        if VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="END_OF_FRAME"
            push!(entries,VirtualTestDrive.RDB_END_OF_FRAME_t())
        elseif VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="START_OF_FRAME"
            push!(entries,VirtualTestDrive.RDB_START_OF_FRAME_t())
        else
            push!(entries,message.entries[1])
        end
    
        if VirtualTestDrive.rdb_pkg_id_to_string(message.entry_headers[1].pkgId)=="END_OF_FRAME"
            # if udp_entry != nothing
            #     VirtualTestDrive.write_udp_packet(connection.UDP, udp_entry, message.header.frameNo, message.header.simTime)
            # end
            #println(message.header)
            finish=true
        end
    end
    #write(connection.SCP, SCPmessage)
    if external_connect == false
        disconnect!(connection)
    end
    return entries
end


###Xiaobai