# Frozone-scaled nbody benchmark: 2 steps instead of full simulation

SOLAR_MASS = 4 * Math::PI**2
DAYS_PER_YEAR = 365.24

class Planet
  attr_accessor :x, :y, :z, :vx, :vy, :vz, :mass

  def initialize(x, y, z, vx, vy, vz, mass)
    @x, @y, @z = x, y, z
    @vx, @vy, @vz = vx * DAYS_PER_YEAR, vy * DAYS_PER_YEAR, vz * DAYS_PER_YEAR
    @mass = mass * SOLAR_MASS
  end
end

BODIES = [
  # Sun
  Planet.new(0, 0, 0, 0, 0, 0, 1.0),
  # Jupiter
  Planet.new(4.84143144246472090, -1.16032004402742839, -0.103622044471843992,
             0.00166007664274403694, 0.00769901118419740425, -0.0000690460016972063023,
             0.000954791938424326609),
  # Saturn
  Planet.new(8.34336671824457987, 4.12479856412430479, -0.403523417114321381,
             -0.00276742510726862411, 0.00499852801234917238, 0.0000230417297573763929,
             0.000285885980666130812),
]

def advance(bodies, dt)
  n = bodies.length
  i = 0
  while i < n
    bi = bodies[i]
    j = i + 1
    while j < n
      bj = bodies[j]
      dx = bi.x - bj.x
      dy = bi.y - bj.y
      dz = bi.z - bj.z
      distance = Math.sqrt(dx*dx + dy*dy + dz*dz)
      mag = dt / (distance * distance * distance)
      bi.vx -= dx * bj.mass * mag
      bi.vy -= dy * bj.mass * mag
      bi.vz -= dz * bj.mass * mag
      bj.vx += dx * bi.mass * mag
      bj.vy += dy * bi.mass * mag
      bj.vz += dz * bi.mass * mag
      j += 1
    end
    i += 1
  end
  i = 0
  while i < n
    b = bodies[i]
    b.x += dt * b.vx
    b.y += dt * b.vy
    b.z += dt * b.vz
    i += 1
  end
end

run_benchmark(3) do
  50.times { advance(BODIES, 0.01) }
end
