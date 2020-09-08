buf = IOBuffer()

##

function watch(rd)
    while !eof(rd) # blocks until something is available
        nb = bytesavailable(rd)

        write(buf, read(rd, nb))


    end
end

##

rd, wr = redirect_stdout()  