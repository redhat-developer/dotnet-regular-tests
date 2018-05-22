using System.Collections.Generic;
using System;
namespace partTest
{
    public class Part : IEquatable<Part> , IComparable<Part>
    {
        public string PartName { get; set; }

        public int PartId { get; set; }

        public override string ToString()
        {
            return "ID: " + PartId + "   Name: " + PartName;
        }
        public override bool Equals(object obj)
        {
            if (obj == null) return false;
            Part objAsPart = obj as Part;
            if (objAsPart == null) return false;
            else return Equals(objAsPart);
        }
        public int SortByNameAscending(string name1, string name2)
        {

            return name1.CompareTo(name2);
        }

        // Default comparer for Part type.
        public int CompareTo(Part comparePart)
        {
            // A null value means that this object is greater.
            if (comparePart == null)
                return 1;

            else
                return this.PartId.CompareTo(comparePart.PartId);
        }
        public override int GetHashCode()
        {
            return PartId;
        }
        public bool Equals(Part other)
        {
            if (other == null) return false;
            return (this.PartId.Equals(other.PartId));
        }
        // Should also override == and != operators.

    }
}